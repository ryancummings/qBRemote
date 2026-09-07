import Foundation
import Testing
@testable import qbremote

@MainActor
struct TorrentRefreshSessionTests {
    private let statsJSON = "{\"dl_info_speed\":12,\"up_info_speed\":3,\"dl_info_data\":100,\"up_info_data\":20}"

    @Test("Active refresh restores authentication and publishes torrents and statistics")
    func refresh() async throws {
        let profile = ServerProfile(host: "localhost")
        let credentials = MemorySessionCredentials()
        credentials.passwords[profile.id] = "test-password"
        credentials.cookies[profile.id] = "expired"
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
        viewModel.configure(with: profile, sessionFactory: QBServerSessionFactory(makeService: { url, allowUntrustedSSL in
            QBittorrentAPIService(baseURL: url, allowUntrustedSSL: allowUntrustedSSL, transport: transport)
        }, credentials: credentials))
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
        viewModel.configure(with: profile, sessionFactory: QBServerSessionFactory(makeService: { url, allowUntrustedSSL in
            QBittorrentAPIService(baseURL: url, allowUntrustedSSL: allowUntrustedSSL, transport: transport)
        }, credentials: MemorySessionCredentials()))
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
        viewModel.configure(with: oldProfile, sessionFactory: QBServerSessionFactory(makeService: { url, allowUntrustedSSL in
            QBittorrentAPIService(baseURL: url, allowUntrustedSSL: allowUntrustedSSL, transport: transport)
        }, credentials: MemorySessionCredentials()))
        let refresh = Task { await viewModel.fetchAll() }
        await started.wait()
        viewModel.configure(with: newProfile, sessionFactory: QBServerSessionFactory(makeService: { _, _ in MockQBittorrentAPIService(simulate: false) }, credentials: MemorySessionCredentials()))
        finish.open()
        await refresh.value
        #expect(viewModel.activeProfileId == newProfile.id)
        #expect(viewModel.stats == nil)
        #expect(viewModel.lastUpdated == nil)
        #expect(viewModel.connectionStatus == .connecting)
    }
}
