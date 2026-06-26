import Foundation
import Security

/// HERC-004 — a tiny Keychain helper for tokens and secrets.
///
/// Nothing sensitive ever goes in `UserDefaults`. v3 stores a ~10-year bearer;
/// v4 stores a short-lived access token + refresh token (see `ARCHITECTURE.md` §3).
/// Items are stored as generic passwords keyed by an account string under a fixed
/// service, accessible only after first unlock on this device (no iCloud sync).
public enum Keychain {

    /// Service identifier all Hercules secrets live under.
    public static let service = "dev.hercules.app"

    public enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case encodingFailed
    }

    // MARK: - String convenience

    /// Store (or replace) a UTF-8 string for `account`.
    public static func set(_ value: String, for account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try set(data, for: account)
    }

    /// Read a UTF-8 string for `account`, or `nil` if absent.
    public static func string(for account: String) throws -> String? {
        guard let data = try data(for: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Data

    /// Store (or replace) raw data for `account`.
    public static func set(_ data: Data, for account: String) throws {
        // Delete any existing item first so this is an upsert.
        try? delete(account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Read raw data for `account`, or `nil` if absent.
    public static func data(for account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Delete the item for `account`. No-op if it does not exist.
    public static func delete(_ account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
