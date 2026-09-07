//
//  KeychainService.swift
//  qbremote
//

import Foundation
import Security

/// A simple Keychain wrapper for storing per-server credentials.
/// Keys are scoped to the server's UUID so multiple profiles are supported.
enum KeychainService {

    // MARK: - Key helpers

    private static func passwordKey(for serverID: UUID) -> String {
        "qbr_password_\(serverID.uuidString)"
    }

    private static func cookieKey(for serverID: UUID) -> String {
        "qbr_cookie_\(serverID.uuidString)"
    }

    // MARK: - Public API

    static func savePassword(_ password: String, for serverID: UUID) {
        save(value: password, key: passwordKey(for: serverID))
    }

    static func loadPassword(for serverID: UUID) -> String? {
        load(key: passwordKey(for: serverID))
    }

    static func saveCookie(_ cookie: String, for serverID: UUID) {
        save(value: cookie, key: cookieKey(for: serverID))
    }

    static func loadCookie(for serverID: UUID) -> String? {
        load(key: cookieKey(for: serverID))
    }

    static func deleteCookie(for serverID: UUID) {
        delete(key: cookieKey(for: serverID))
    }

    static func deleteCredentials(for serverID: UUID) {
        delete(key: passwordKey(for: serverID))
        delete(key: cookieKey(for: serverID))
    }

    // Checked access lets profile edits fail without silently losing credentials.
    static func readPassword(for serverID: UUID) throws -> String? {
        try read(key: passwordKey(for: serverID))
    }

    static func readCookie(for serverID: UUID) throws -> String? {
        try read(key: cookieKey(for: serverID))
    }

    static func writePassword(_ value: String?, for serverID: UUID) throws {
        try write(value: value, key: passwordKey(for: serverID))
    }

    static func writeCookie(_ value: String?, for serverID: UUID) throws {
        try write(value: value, key: cookieKey(for: serverID))
    }

    // MARK: - Private CRUD

    private static func save(value: String, key: String) {
        do { try write(value: value, key: key) }
        catch { print("[Keychain] Save failed: \(error.localizedDescription)") }
    }

    private static func load(key: String) -> String? {
        try? read(key: key)
    }

    private static func delete(key: String) {
        try? write(value: nil, key: key)
    }

    private static func write(value: String?, key: String) throws {
        var query = baseQuery(forKey: key)
        guard let value else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
            return
        }
        let data = Data(value.utf8)
        // Update atomically; an unsuccessful write must preserve the existing item.
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw KeychainError(status: status) }
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(query as CFDictionary, nil)
        guard added == errSecSuccess else { throw KeychainError(status: added) }
    }

    private static func read(key: String) throws -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError(status: errSecDecode)
        }
        return value
    }

    private static func baseQuery(forKey key: String) -> [String: Any] {
        // Items live in the app's default access group. There is no Keychain
        // sharing / app-group capability on this target, so no kSecAttrAccessGroup
        // is set. If a share/widget extension is added later, enable the Keychain
        // Sharing capability and set kSecAttrAccessGroup here to share credentials.
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.OneRadStudio.qbremote",
            kSecAttrAccount as String: key
        ]
    }
}

private struct KeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
        "Could not access saved credentials (Keychain error \(status))."
    }
}
