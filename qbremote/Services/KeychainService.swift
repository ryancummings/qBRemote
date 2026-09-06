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

    static func deleteCredentials(for serverID: UUID) {
        delete(key: passwordKey(for: serverID))
        delete(key: cookieKey(for: serverID))
    }

    // MARK: - Private CRUD

    private static func save(value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }

        var query = baseQuery(forKey: key)

        // Delete existing item first, then add
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Keychain] Save failed for key '\(key)': \(status)")
        }
    }

    private static func load(key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func delete(key: String) {
        let query = baseQuery(forKey: key)
        SecItemDelete(query as CFDictionary)
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
