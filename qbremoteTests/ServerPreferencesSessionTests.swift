import Foundation
import SwiftData
import Testing
@testable import qbremote

@MainActor
struct ServerPreferencesSessionTests {
    private let prefsJSON = "{\"listen_port\":6881,\"web_ui_port\":8080,\"use_https\":false,\"up_limit\":2048,\"dl_limit\":3072,\"alt_up_limit\":4096,\"alt_dl_limit\":5120}"

    @Test("Preference reads and writes recover authentication once", arguments: [false, true], [401, 403])
    func retry(saving: Bool, status: Int) async throws {
        let profile = ServerProfile(host: "selected.local", port: 8080)
        let credentials = MemorySessionCredentials()
        credentials.passwords[profile.id] = "secret"
        credentials.cookies[profile.id] = "saved"
        var attempts = 0
        var logins = 0
        let target = saving ? "setPreferences" : "preferences"
        let transport = SessionTransport { request in
            #expect(request.url?.host == "selected.local")
            if request.url?.lastPathComponent == "login" {
                logins += 1
                return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"])
            }
            if request.url?.lastPathComponent == target {
                attempts += 1
                if attempts == 1 { return (status, "", [:]) }
            }
            return (200, prefsJSON, [:])
        }
        let (viewModel, container) = try makeViewModel(profile, transport, credentials: credentials)
        defer { withExtendedLifetime(container) {} }
        await viewModel.loadPreferences()
        if saving { #expect(await viewModel.savePreferences()) }
        #expect(attempts == 2)
        #expect(logins == 1)
        #expect(viewModel.connectionStatus == .connected)
        #expect(!viewModel.showError)
        #expect(!viewModel.isLoading && !viewModel.isSaving)
        #expect(viewModel.upLimitKBString == "2")
        #expect(viewModel.dlLimitKBString == "3")
        #expect(viewModel.altUpLimitKBString == "4")
        #expect(viewModel.altDlLimitKBString == "5")
    }

    @Test("Saving converts limits and signals reconnect for either port or HTTPS changes", arguments: [false, true])
    func conversionsAndReconnect(changeHTTPS: Bool) async throws {
        let profile = ServerProfile(host: "localhost", port: 8080)
        let oldUpdated = Date(timeIntervalSince1970: 10)
        profile.lastUpdated = oldUpdated
        var saved: ServerPreferences?
        let transport = SessionTransport { request in
            if request.url?.lastPathComponent == "setPreferences" {
                let body = try #require(String(data: request.httpBody ?? Data(), encoding: .utf8))
                let json = try #require(String(body.dropFirst("json=".count)).removingPercentEncoding)
                saved = try JSONDecoder().decode(ServerPreferences.self, from: Data(json.utf8))
                return (200, "", [:])
            }
            return (200, prefsJSON, [:])
        }
        let (viewModel, container) = try makeViewModel(profile, transport)
        defer { withExtendedLifetime(container) {} }
        await viewModel.loadPreferences()
        #expect(!viewModel.hasConnectionSettingsChanged)
        if changeHTTPS { viewModel.preferences?.use_https = true } else { viewModel.webUIPortString = "9090" }
        #expect(viewModel.hasConnectionSettingsChanged)
        viewModel.upLimitKBString = "7"
        viewModel.dlLimitKBString = "8"
        viewModel.altUpLimitKBString = "9"
        viewModel.altDlLimitKBString = "10"
        #expect(await viewModel.savePreferences())
        #expect(saved?.up_limit == 7168)
        #expect(saved?.dl_limit == 8192)
        #expect(saved?.alt_up_limit == 9216)
        #expect(saved?.alt_dl_limit == 10240)
        #expect(profile.port == (changeHTTPS ? 8080 : 9090))
        #expect(profile.useHTTPS == changeHTTPS)
        #expect(profile.lastUpdated > oldUpdated)
    }

    @Test("Preference failures have bounded retries and preserve the profile",
          arguments: [false, true], [401, 403, 500, -1])
    func failure(saving: Bool, status: Int) async throws {
        let profile = ServerProfile(host: "localhost", port: 8080)
        let credentials = MemorySessionCredentials()
        credentials.passwords[profile.id] = "secret"
        let transport = SessionTransport { _ in (200, prefsJSON, [:]) }
        let (viewModel, container) = try makeViewModel(profile, transport, credentials: credentials)
        defer { withExtendedLifetime(container) {} }
        await viewModel.loadPreferences()
        viewModel.webUIPortString = "9090"
        let oldUpdated = profile.lastUpdated
        var attempts = 0
        var logins = 0
        transport.handler = { request in
            if request.url?.lastPathComponent == "login" {
                logins += 1
                return (200, "Ok.", ["Set-Cookie": "SID=fresh; Path=/"])
            }
            attempts += 1
            if status == -1 { throw URLError(.timedOut) }
            return (status, "", [:])
        }
        if saving { #expect(await !viewModel.savePreferences()) } else { await viewModel.loadPreferences() }
        #expect(attempts == ((status == 401 || status == 403) ? 2 : 1))
        #expect(logins == ((status == 401 || status == 403) ? 1 : 0))
        #expect(viewModel.showError)
        #expect(profile.port == 8080)
        #expect(profile.lastUpdated == oldUpdated)
        #expect(!viewModel.isLoading && !viewModel.isSaving)
        if status == 500 {
            #expect(viewModel.connectionStatus == .connected)
        } else if case .error = viewModel.connectionStatus {} else {
            Issue.record("Expected failed connection")
        }
    }

    private func makeViewModel(
        _ profile: ServerProfile, _ transport: SessionTransport,
        credentials: MemorySessionCredentials = MemorySessionCredentials()
    ) throws -> (ServerPreferencesViewModel, ModelContainer) {
        let container = try ModelContainer(for: ServerProfile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.insert(profile)
        let viewModel = ServerPreferencesViewModel()
        viewModel.configure(with: profile, context: container.mainContext, sessionFactory: QBServerSessionFactory(makeService: { url, allowUntrustedSSL in
            QBittorrentAPIService(baseURL: url, allowUntrustedSSL: allowUntrustedSSL, transport: transport)
        }, credentials: credentials))
        return (viewModel, container)
    }
}
