import Foundation

/// Credential persistence contract. Implemented over the existing `Keychain`;
/// tokens never touch `UserDefaults` (Safeguard 3).
public protocol TokenStoring: Sendable {
    func saveV3(_ c: V3Credential) throws
    func loadV3() throws -> V3Credential?
    func saveV4(_ p: V4TokenPair) throws
    func loadV4() throws -> V4TokenPair?
    func clearAll() throws
}

/// `TokenStoring` over the existing `Keychain`, with typed accounts
/// `auth.v3` / `auth.v4`. Credentials are JSON-encoded before storage.
public struct TokenStore: TokenStoring {
    private enum Account {
        static let v3 = "auth.v3"
        static let v4 = "auth.v4"
    }

    public init() {}

    public func saveV3(_ c: V3Credential) throws { try save(c, account: Account.v3) }
    public func loadV3() throws -> V3Credential? { try load(V3Credential.self, account: Account.v3) }
    public func saveV4(_ p: V4TokenPair) throws { try save(p, account: Account.v4) }
    public func loadV4() throws -> V4TokenPair? { try load(V4TokenPair.self, account: Account.v4) }

    /// Delete both accounts — used on sign-out / stale-token reset.
    public func clearAll() throws {
        try Keychain.delete(Account.v3)
        try Keychain.delete(Account.v4)
    }

    private func save<T: Encodable>(_ value: T, account: String) throws {
        let data = try JSONEncoder().encode(value)
        try Keychain.set(data, for: account)
    }

    private func load<T: Decodable>(_ type: T.Type, account: String) throws -> T? {
        guard let data = try Keychain.data(for: account) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
