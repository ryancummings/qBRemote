import Foundation

// MARK: - Typed Operations

/// Only this file can construct operations. Each value replays one API call.
struct QBOperation<Value: Sendable> {
    fileprivate let execute: @MainActor (any QBittorrentAPIServiceProtocol) async throws -> Value

    private init(_ execute: @escaping @MainActor (any QBittorrentAPIServiceProtocol) async throws -> Value) {
        self.execute = execute
    }
}

extension QBOperation where Value == [Torrent] {
    static func torrents(filter: TorrentFilter = .all) -> Self {
        Self { try await $0.getTorrents(filter: filter) }
    }
}

extension QBOperation where Value == GlobalStats {
    static var globalStats: Self {
        Self { try await $0.getGlobalStats() }
    }
}

extension QBOperation where Value == String {
    static var defaultSavePath: Self {
        Self { try await $0.getDefaultSavePath() }
    }
}

extension QBOperation where Value == [String: QBittorrentAPIService.TorrentCategory] {
    static var torrentCategories: Self {
        Self { try await $0.getTorrentCategories() }
    }
}

extension QBOperation where Value == Void {
    static func addTorrentByURL(_ url: String, savePath: String) -> Self {
        Self { try await $0.addTorrentByURL(url, savePath: savePath) }
    }

    static func addTorrentByData(_ data: Data, filename: String, savePath: String) -> Self {
        Self { try await $0.addTorrentByData(data, filename: filename, savePath: savePath) }
    }
}

// MARK: - Credentials

@MainActor
protocol QBSessionCredentials: AnyObject, Sendable {
    func loadPassword(for id: UUID) -> String?
    func loadCookie(for id: UUID) -> String?
    func saveCookie(_ cookie: String, for id: UUID)
    func deleteCookie(for id: UUID)
}

private final class KeychainSessionCredentials: QBSessionCredentials {
    func loadPassword(for id: UUID) -> String? { KeychainService.loadPassword(for: id) }
    func loadCookie(for id: UUID) -> String? { KeychainService.loadCookie(for: id) }
    func saveCookie(_ cookie: String, for id: UUID) { KeychainService.saveCookie(cookie, for: id) }
    func deleteCookie(for id: UUID) { KeychainService.deleteCookie(for: id) }
}

// MARK: - Server Session

/// Authenticated access to one saved profile. Scheduling belongs to the workflow.
@Observable
final class QBServerSession {
    private(set) var connectionStatus: ConnectionStatus = .connecting

    private let profileID: UUID
    private let username: String
    private let service: any QBittorrentAPIServiceProtocol
    private let credentials: any QBSessionCredentials
    private var loginTask: Task<Void, Error>?
    private var authenticationGeneration = 0
    private var activeOperations = 0
    private var failureRevision = 0

    init(
        profile: ServerProfile,
        service: (any QBittorrentAPIServiceProtocol)? = nil,
        credentials: (any QBSessionCredentials)? = nil
    ) throws {
        guard let url = profile.baseURL else { throw QBError.invalidURL }
        self.profileID = profile.id
        self.username = profile.username
        self.service = service ?? QBittorrentAPIService(baseURL: url, allowUntrustedSSL: profile.allowUntrustedSSL)
        self.credentials = credentials ?? KeychainSessionCredentials()
        if let cookie = self.credentials.loadCookie(for: profile.id), !cookie.isEmpty {
            self.service.setSessionCookie(cookie)
        } else {
            self.service.setSessionCookie(nil)
        }
    }

    isolated deinit {
        loginTask?.cancel()
    }

    func run<Value>(_ operation: QBOperation<Value>) async throws -> Value {
        try Task.checkCancellation()
        activeOperations += 1
        defer {
            activeOperations -= 1
            if activeOperations == 0 { loginTask = nil }
        }
        let revision = failureRevision
        let generation = authenticationGeneration
        do {
            // New operations also wait for an authentication attempt already in flight.
            if let loginTask { try await finishLogin(loginTask) }
            try Task.checkCancellation()
            let result: Value
            do {
                result = try await operation.execute(service)
            } catch {
                try Task.checkCancellation()
                guard Self.isAuthenticationRejection(error) else { throw error }
                try await authenticate(after: generation)
                try Task.checkCancellation()
                // No catch-and-retry around this call: the retry budget is exactly one.
                result = try await operation.execute(service)
            }
            try Task.checkCancellation()
            if revision == failureRevision { connectionStatus = .connected }
            return result
        } catch {
            if Self.isCancellation(error) || Task.isCancelled { throw CancellationError() }
            if Self.isAuthenticationRejection(error) {
                invalidateCookie()
            }
            if Self.failsConnection(error) {
                failureRevision += 1
                connectionStatus = .error(error.localizedDescription)
            }
            throw error
        }
    }

    private func authenticate(after generation: Int) async throws {
        // A delayed rejection from the old cookie shares even a completed login.
        if generation != authenticationGeneration, let loginTask {
            try await finishLogin(loginTask)
            return
        }
        invalidateCookie()
        authenticationGeneration += 1
        connectionStatus = .connecting
        let service = self.service
        let credentials = self.credentials
        let profileID = self.profileID
        let username = self.username
        let revision = failureRevision
        let task = Task { [weak self] in
            guard let password = credentials.loadPassword(for: profileID) else {
                throw QBError.loginFailed("No password stored. Please re-enter credentials.")
            }
            let sid = try await service.login(username: username, password: password)
            try Task.checkCancellation()
            service.setSessionCookie(sid.isEmpty ? nil : sid)
            if !sid.isEmpty { credentials.saveCookie(sid, for: profileID) }
            if self?.failureRevision == revision { self?.connectionStatus = .connected }
        }
        loginTask = task
        // Keep the completed attempt so late failures share its result, including errors.
        try await finishLogin(task)
    }

    private func finishLogin(_ task: Task<Void, Error>) async throws {
        do {
            try await task.value
        } catch {
            if Self.isCancellation(error) { throw error }
            if let qbError = error as? QBError, Self.failsConnection(qbError) { throw qbError }
            throw QBError.loginFailed(error.localizedDescription)
        }
    }

    private func invalidateCookie() {
        service.setSessionCookie(nil)
        credentials.deleteCookie(for: profileID)
    }

    private static func isAuthenticationRejection(_ error: Error) -> Bool {
        guard let error = error as? QBError else { return false }
        switch error {
        case .unauthorized, .forbidden: return true
        default:                       return false
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let error = error as? URLError, error.code == .cancelled { return true }
        if case .networkError(let underlying) = error as? QBError {
            return isCancellation(underlying)
        }
        return false
    }

    private static func failsConnection(_ error: Error) -> Bool {
        guard let error = error as? QBError else { return true }
        switch error {
        case .unauthorized, .forbidden, .loginFailed, .networkError, .invalidURL: return true
        case .decodingFailed, .requestFailed:                                  return false
        }
    }
}
