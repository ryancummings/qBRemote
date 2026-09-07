import Foundation
import SwiftData

@MainActor
protocol ServerProfileCredentials {
    func password(for id: UUID) throws -> String?
    func cookie(for id: UUID) throws -> String?
    func setPassword(_ value: String?, for id: UUID) throws
    func setCookie(_ value: String?, for id: UUID) throws
}

struct KeychainProfileCredentials: ServerProfileCredentials {
    func password(for id: UUID) throws -> String? { try KeychainService.readPassword(for: id) }
    func cookie(for id: UUID) throws -> String? { try KeychainService.readCookie(for: id) }
    func setPassword(_ value: String?, for id: UUID) throws { try KeychainService.writePassword(value, for: id) }
    func setCookie(_ value: String?, for id: UUID) throws { try KeychainService.writeCookie(value, for: id) }
}

@Observable
final class ServerProfileDraft {
    var name = ""
    var host = ""
    var port = ""
    var username = "admin"
    var password = ""
    var useHTTPS = false
    var allowUntrustedSSL = false
    var pollingInterval = 5.0
    private(set) var profile: ServerProfile?
    private(set) var connectionTestResult: ConnectionTestResult = .idle
    var error: String?

    private let id: UUID
    private let credentials: any ServerProfileCredentials

    init(profile: ServerProfile?, credentials: any ServerProfileCredentials = KeychainProfileCredentials()) {
        self.profile = profile
        self.id = profile?.id ?? UUID()
        self.credentials = credentials
        if let profile {
            name = profile.name
            host = profile.host
            port = profile.port.map(String.init) ?? ""
            username = profile.username
            useHTTPS = profile.useHTTPS
            allowUntrustedSSL = profile.allowUntrustedSSL
            pollingInterval = profile.pollingInterval
            do {
                password = try credentials.password(for: profile.id) ?? ""
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    var isNew: Bool { profile == nil }
    var canSave: Bool { !host.isEmpty && !username.isEmpty }
    var isTestingConnection: Bool {
        if case .testing = connectionTestResult { return true }
        return false
    }

    // MARK: - Unsaved Connection Test

    func testConnection(using factory: QBServerSessionFactory = QBServerSessionFactory()) async {
        connectionTestResult = .testing
        let connection = QBServerConnection(
            host: host, port: Int(port), useHTTPS: useHTTPS,
            allowUntrustedSSL: allowUntrustedSSL, username: username
        )
        do {
            try await factory.testConnection(connection, password: password)
            connectionTestResult = .success("Connected successfully!")
        } catch is CancellationError {
            connectionTestResult = .idle
        } catch {
            connectionTestResult = .failure(error.localizedDescription)
        }
    }

    // MARK: - Persistence

    @discardableResult
    func save(in context: ModelContext, persist: (ModelContext) throws -> Void = { try $0.save() }) -> Bool {
        error = nil
        let candidate = profile ?? ServerProfile(id: id)
        let previous = SavedFields(candidate)
        let isInsertion = profile == nil
        do {
            let oldPassword = try credentials.password(for: id)
            let oldCookie = try credentials.cookie(for: id)
            var fieldsApplied = false
            do {
                try credentials.setPassword(password, for: id)
                if isInsertion || candidate.host != host || candidate.port != Int(port)
                    || candidate.username != username || candidate.useHTTPS != useHTTPS
                    || candidate.allowUntrustedSSL != allowUntrustedSSL || oldPassword != password {
                    try credentials.setCookie(nil, for: id)
                }
                fieldsApplied = true
                candidate.name = name
                candidate.host = host
                candidate.port = Int(port)
                candidate.username = username
                candidate.useHTTPS = useHTTPS
                candidate.allowUntrustedSSL = allowUntrustedSSL
                candidate.pollingInterval = pollingInterval
                candidate.lastUpdated = .now
                if isInsertion { context.insert(candidate) }
                try persist(context)
            } catch {
                if fieldsApplied { previous.restore(candidate) }
                if isInsertion, candidate.modelContext != nil { context.delete(candidate) }
                try restoreCredentials(password: oldPassword, cookie: oldCookie, after: error)
                throw error
            }
            profile = candidate
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func delete(in context: ModelContext, persist: (ModelContext) throws -> Void = { try $0.save() }) -> Bool {
        guard let profile else { return false }
        error = nil
        do {
            let oldPassword = try credentials.password(for: id)
            let oldCookie = try credentials.cookie(for: id)
            var deleted = false
            do {
                try credentials.setPassword(nil, for: id)
                try credentials.setCookie(nil, for: id)
                context.delete(profile)
                deleted = true
                try persist(context)
            } catch {
                if deleted { context.insert(profile) }
                try restoreCredentials(password: oldPassword, cookie: oldCookie, after: error)
                throw error
            }
            self.profile = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func restoreCredentials(password: String?, cookie: String?, after original: Error) throws {
        var failures: [String] = []
        do {
            try credentials.setPassword(password, for: id)
        } catch {
            failures.append(error.localizedDescription)
        }
        do {
            try credentials.setCookie(cookie, for: id)
        } catch {
            failures.append(error.localizedDescription)
        }
        if !failures.isEmpty {
            throw CredentialRollbackError(message: "\(original.localizedDescription) Credential restoration failed: \(failures.joined(separator: "; "))")
        }
    }
}

private struct CredentialRollbackError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Restores only this profile's edits; other pending context changes are untouched.
private struct SavedFields {
    let name: String
    let host: String
    let port: Int?
    let username: String
    let useHTTPS: Bool
    let allowUntrustedSSL: Bool
    let pollingInterval: Double
    let lastUpdated: Date

    init(_ profile: ServerProfile) {
        name = profile.name
        host = profile.host
        port = profile.port
        username = profile.username
        useHTTPS = profile.useHTTPS
        allowUntrustedSSL = profile.allowUntrustedSSL
        pollingInterval = profile.pollingInterval
        lastUpdated = profile.lastUpdated
    }

    func restore(_ profile: ServerProfile) {
        profile.name = name
        profile.host = host
        profile.port = port
        profile.username = username
        profile.useHTTPS = useHTTPS
        profile.allowUntrustedSSL = allowUntrustedSSL
        profile.pollingInterval = pollingInterval
        profile.lastUpdated = lastUpdated
    }
}
