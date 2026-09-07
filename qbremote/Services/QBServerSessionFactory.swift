import Foundation

/// Connection-test input contains no saved model or credential-store reference.
struct QBServerConnection {
    let host: String
    let port: Int?
    let useHTTPS: Bool
    let allowUntrustedSSL: Bool
    let username: String

    var baseURL: URL? {
        let scheme = useHTTPS ? "https" : "http"
        return URL(string: "\(scheme)://\(host)\(port.map { ":\($0)" } ?? "")")
    }
}

struct QBServerSessionFactory {
    private let makeService: @MainActor (URL, Bool) -> any QBittorrentAPIServiceProtocol

    init(makeService: @escaping @MainActor (URL, Bool) -> any QBittorrentAPIServiceProtocol = Self.productionService) {
        self.makeService = makeService
    }

    func session(for profile: ServerProfile) throws -> QBServerSession {
        guard let url = profile.baseURL else { throw QBError.invalidURL }
        return try QBServerSession(profile: profile, service: makeService(url, profile.allowUntrustedSSL))
    }

    func testConnection(_ connection: QBServerConnection, password: String) async throws {
        guard let url = connection.baseURL else { throw QBError.invalidURL }
        let service = makeService(url, connection.allowUntrustedSSL)
        let sid = try await service.login(username: connection.username, password: password)
        if !sid.isEmpty { try? await service.logout() }
        try Task.checkCancellation()
    }

    private static func productionService(url: URL, allowUntrustedSSL: Bool) -> any QBittorrentAPIServiceProtocol {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-isUITest") || UserDefaults.standard.bool(forKey: "isDemoMode") {
            return MockQBittorrentAPIService()
        }
        #endif
        return QBittorrentAPIService(baseURL: url, allowUntrustedSSL: allowUntrustedSSL)
    }
}
