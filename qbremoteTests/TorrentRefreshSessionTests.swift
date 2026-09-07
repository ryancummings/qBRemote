import Foundation
import Testing
@testable import qbremote

@MainActor
struct TorrentRefreshSessionTests {
    private let statsJSON = "{\"dl_info_speed\":12,\"up_info_speed\":3,\"dl_info_data\":100,\"up_info_data\":20}"

    @Test("Active refresh restores authentication and publishes torrents and statistics")
    func refresh() async throws {
        let profile = ServerProfile(host: "localhost")
        KeychainService.savePassword("test-password", for: profile.id)
        KeychainService.saveCookie("expired", for: profile.id)
        defer { KeychainService.deleteCredentials(for: profile.id) }
        var logins = 0
        let transport = SessionTransport { request in
            if request.url?.path == "/api/v2/auth/login" {
                logins += 1
                return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"])
            }
            guard request.value(forHTTPHeaderField: "Cookie") == "SID=fresh" else {
                return (403, "", [:])
            }
            return (200, request.url?.path == "/api/v2/transfer/info" ? statsJSON : "[]", [:])
        }
        let viewModel = TorrentListViewModel()
        viewModel.configure(with: profile, injectedService: QBittorrentAPIService(
            baseURL: try #require(profile.baseURL), transport: transport
        ))
        await viewModel.fetchAll()
        #expect(logins == 1)
        #expect(viewModel.torrents.isEmpty)
        #expect(viewModel.stats?.downloadSpeed == 12)
        #expect(viewModel.lastUpdated != nil)
        #expect(viewModel.error == nil)
        #expect(viewModel.connectionStatus == .connected)
        transport.handler = { _ in (500, "", [:]) }
        await viewModel.fetchAll()
        #expect(viewModel.error != nil)
        #expect(viewModel.connectionStatus == .connected)
        #expect(viewModel.stats?.downloadSpeed == 12)
    }

    @Test("A startup transport error does not trigger password login")
    func startupTransportError() async throws {
        let profile = ServerProfile(host: "localhost")
        let transport = SessionTransport { _ in throw URLError(.timedOut) }
        let viewModel = TorrentListViewModel()
        viewModel.configure(with: profile, injectedService: QBittorrentAPIService(
            baseURL: try #require(profile.baseURL), transport: transport
        ))
        await viewModel.start(profile: profile)
        defer { viewModel.stopPolling() }
        #expect(transport.requests.count == 1)
        #expect(viewModel.error != nil)
        #expect(!viewModel.isLoading)
        if case .error = viewModel.connectionStatus {} else { Issue.record("Expected a failed connection") }
    }

    @Test("A previous profile's delayed refresh does not overwrite the active profile")
    func profileSwitch() async throws {
        let oldProfile = ServerProfile(host: "old.local")
        let newProfile = ServerProfile(host: "new.local")
        let started = SessionGate()
        let finish = SessionGate()
        let transport = SessionTransport { request in
            started.open()
            await finish.wait()
            return (200, request.url?.path == "/api/v2/transfer/info" ? statsJSON : "[]", [:])
        }
        let viewModel = TorrentListViewModel()
        viewModel.configure(with: oldProfile, injectedService: QBittorrentAPIService(
            baseURL: try #require(oldProfile.baseURL), transport: transport
        ))
        let refresh = Task { await viewModel.fetchAll() }
        await started.wait()
        viewModel.configure(with: newProfile, injectedService: MockQBittorrentAPIService(simulate: false))
        finish.open()
        await refresh.value
        #expect(viewModel.activeProfileId == newProfile.id)
        #expect(viewModel.stats == nil)
        #expect(viewModel.lastUpdated == nil)
        #expect(viewModel.connectionStatus == .connecting)
    }
}
