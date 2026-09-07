import Foundation
import SwiftData
import Testing
@testable import qbremote

@MainActor
struct SessionWorkflowBoundaryTests {
    @Test("Saved-profile workflows use the session factory and restore the selected cookie")
    func sharedFactoryBoundary() async throws {
        let profile = ServerProfile(host: "selected.local", port: 9443, useHTTPS: true, allowUntrustedSSL: true)
        let credentials = MemorySessionCredentials()
        credentials.cookies[profile.id] = "saved"
        let transport = SessionTransport { request in
            #expect(request.value(forHTTPHeaderField: "Cookie") == "SID=saved")
            #expect(request.url?.host == "selected.local")
            #expect(request.url?.scheme == "https")
            #expect(request.url?.port == 9443)
            switch request.url?.lastPathComponent {
            case "info" where request.url?.path.contains("torrents") == true: return (200, "[]", [:])
            case "info": return (200, "{\"dl_info_speed\":1,\"up_info_speed\":2,\"dl_info_data\":3,\"up_info_data\":4}", [:])
            case "preferences": return (200, "{\"web_ui_port\":9443}", [:])
            default: Issue.record("Unexpected request"); return (500, "", [:])
            }
        }
        var created = 0
        let factory = QBServerSessionFactory(makeService: { url, allowUntrustedSSL in
            created += 1
            #expect(allowUntrustedSSL)
            return QBittorrentAPIService(baseURL: url, allowUntrustedSSL: allowUntrustedSSL, transport: transport)
        }, credentials: credentials)
        let list = TorrentListViewModel()
        list.configure(with: profile, sessionFactory: factory)
        await list.fetchAll()
        #expect(list.connectionStatus == .connected)
        let external = ExternalAddTorrentViewModel()
        await external.prepare(profile: profile, sessionFactory: factory)
        #expect(external.session?.connectionStatus == .connected)
        let container = try ModelContainer(for: ServerProfile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        defer { withExtendedLifetime(container) {} }
        container.mainContext.insert(profile)
        let preferences = ServerPreferencesViewModel()
        preferences.configure(with: profile, context: container.mainContext, sessionFactory: factory)
        await preferences.loadPreferences()
        #expect(preferences.preferences?.web_ui_port == 9443)
        #expect(created == 3)
        #expect(credentials.cookies[profile.id] == "saved")
    }
}
