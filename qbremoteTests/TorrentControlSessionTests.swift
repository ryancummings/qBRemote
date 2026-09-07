import Foundation
import Testing
@testable import qbremote

@MainActor
struct TorrentControlSessionTests {
    enum Control: CaseIterable, Sendable {
        case pause, resume, delete, deleteFiles, move

        var path: String {
            switch self {
            case .move:                 return "/api/v2/torrents/setLocation"
            case .pause:                return "/api/v2/torrents/stop"
            case .resume:               return "/api/v2/torrents/start"
            case .delete, .deleteFiles: return "/api/v2/torrents/delete"
            }
        }

        var body: String {
            switch self {
            case .move:           return "hashes=target&location=%2Fdownloads"
            case .pause, .resume: return "hashes=target"
            case .delete:         return "hashes=target&deleteFiles=false"
            case .deleteFiles:    return "hashes=target&deleteFiles=true"
            }
        }

        func perform(on viewModel: TorrentListViewModel, torrent: Torrent) async {
            switch self {
            case .move:        await viewModel.move(torrent: torrent, to: "/downloads")
            case .pause:       await viewModel.pause(torrent: torrent)
            case .resume:      await viewModel.resume(torrent: torrent)
            case .delete:      await viewModel.delete(torrent: torrent)
            case .deleteFiles: await viewModel.delete(torrent: torrent, deleteFiles: true)
            }
        }
    }

    @Test("Controls recover authentication once, keeping pending state through one refresh",
          arguments: Control.allCases, [401, 403])
    func authenticationRecovery(control: Control, status: Int) async throws {
        try await exercise(control, firstStatus: status, retryStatus: 200, expectedMutations: 2, expectedLogins: 1)
    }

    @Test("Controls never replay non-authentication failures or retry a second rejection",
          arguments: Control.allCases, [400, 404, 500, 401, 403, -1])
    func boundedFailure(control: Control, status: Int) async throws {
        let rejected = status == 401 || status == 403
        try await exercise(control, firstStatus: status, retryStatus: status,
                           expectedMutations: rejected ? 2 : 1, expectedLogins: rejected ? 1 : 0)
    }

    @Test("Typed controls preserve selected hashes and deletion mode")
    func typedControls() async throws {
        let profile = ServerProfile(host: "localhost")
        let transport = SessionTransport { _ in (200, "", [:]) }
        let session = try QBServerSession(
            profile: profile,
            service: QBittorrentAPIService(baseURL: #require(profile.baseURL), transport: transport),
            credentials: MemorySessionCredentials()
        )
        try await session.run(.pauseTorrents(hashes: ["one", "two"]))
        try await session.run(.resumeTorrents(hashes: ["one", "two"]))
        try await session.run(.deleteTorrents(hashes: ["one", "two"], deleteFiles: true))
        #expect(transport.requests.map { $0.url?.lastPathComponent } == ["stop", "start", "delete"])
        #expect(transport.requests.map { String(data: $0.httpBody ?? Data(), encoding: .utf8) }
                == ["hashes=one|two", "hashes=one|two", "hashes=one|two&deleteFiles=true"])
    }

    private func exercise(
        _ control: Control, firstStatus: Int, retryStatus: Int, expectedMutations: Int, expectedLogins: Int
    ) async throws {
        let profile = ServerProfile(host: "selected.local")
        KeychainService.savePassword("secret", for: profile.id)
        KeychainService.saveCookie("saved", for: profile.id)
        defer { KeychainService.deleteCredentials(for: profile.id) }
        let viewModel = TorrentListViewModel()
        let torrent = Torrent(hash: "target", name: "Target", state: .downloading, progress: 0, size: 100)
        var mutations = 0
        var logins = 0
        var refreshes = 0
        let transport = SessionTransport { request in
            #expect(request.url?.host == "selected.local")
            #expect(viewModel.pendingHashes == [torrent.hash])
            if request.url?.path == "/api/v2/auth/login" {
                logins += 1
                return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"])
            }
            if request.url?.path == control.path {
                mutations += 1
                #expect(String(data: request.httpBody ?? Data(), encoding: .utf8) == control.body)
                #expect(request.value(forHTTPHeaderField: "Cookie") == (mutations == 1 ? "SID=saved" : "SID=fresh"))
                if firstStatus == -1 { throw URLError(.timedOut) }
                return (mutations == 1 ? firstStatus : retryStatus, "", [:])
            }
            if request.url?.path == "/api/v2/torrents/info" {
                refreshes += 1
                return (200, "[]", [:])
            }
            return (200, "{\"dl_info_speed\":12,\"up_info_speed\":3,\"dl_info_data\":100,\"up_info_data\":20}", [:])
        }
        viewModel.configure(with: profile, sessionFactory: QBServerSessionFactory(makeService: { url, allowUntrustedSSL in
            QBittorrentAPIService(baseURL: url, allowUntrustedSSL: allowUntrustedSSL, transport: transport)
        }))
        await control.perform(on: viewModel, torrent: torrent)
        #expect(mutations == expectedMutations)
        #expect(logins == expectedLogins)
        #expect(refreshes == 1)
        #expect(viewModel.pendingHashes.isEmpty)
        #expect(viewModel.lastUpdated != nil)
        #expect(viewModel.stats?.downloadSpeed == 12)
    }
}
