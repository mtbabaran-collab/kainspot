//
//  KeychainStore.swift
//  KainSpot
//
//  Tiny Security-framework wrapper for secrets (the Gemini API key). Secrets never go in
//  UserDefaults or source code. Feature: AI assistant (secure key storage).
//

import Foundation
import Security

/// Stores strings as generic passwords under the app's own service name.
enum KeychainStore {

    /// Keychain "service" groups every item this app saves.
    static let service = "com.kainspot.KainSpot"

    /// Account name used for the Gemini API key.
    static let geminiAccount = "geminiApiKey"

    /// Base query that identifies one item (service + account).
    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    /// Saves (or replaces) a value. Returns true on success.
    /// Delete-then-add keeps the code simple and avoids a separate SecItemUpdate path.
    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        delete(key)
        var query = baseQuery(for: key)
        query[kSecValueData as String] = Data(value.utf8)
        // Readable after the first unlock so a background refresh could use it; never synced off-device.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Reads a value, or nil when it is missing or unreadable.
    static func read(_ key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Removes a value; deleting a missing item is not an error.
    static func delete(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    /// The Gemini key: the GEMINI_API_KEY environment variable wins (Xcode scheme / CI demos),
    /// otherwise the key the user pasted in the app and we saved in the keychain. Empty values count as missing.
    static var geminiKey: String? {
        if let fromEnvironment = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !fromEnvironment.isEmpty {
            return fromEnvironment
        }
        guard let stored = read(geminiAccount)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !stored.isEmpty else { return nil }
        return stored
    }
}
