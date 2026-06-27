import Foundation

/// Client credentials + member id. **One client pair is shared by both realms.**
/// Loaded from a gitignored `Secrets.plist` on first run, seeded into the
/// Keychain, and read from the Keychain thereafter. Secret values are never
/// logged (Norm 4 / Safeguard 3).
public struct AppSecrets: Sendable {
    public let clientID: String
    public let clientSecret: String
    public let memberID: String

    public init(clientID: String, clientSecret: String, memberID: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.memberID = memberID
    }

    private enum Account {
        static let seeded = "secrets.seeded"
        static let clientID = "secrets.clientID"
        static let clientSecret = "secrets.clientSecret"
        static let memberID = "secrets.memberID"
    }

    /// Resolve secrets. The bundled (gitignored) `Secrets.plist` is the editable
    /// source of truth for this single-user app: when present it wins and
    /// (re)seeds the Keychain, so edits to the plist take effect on the next
    /// launch. Builds shipped without the plist fall back to the previously
    /// seeded Keychain values. Throws `AuthError.missingSecrets` if neither
    /// source resolves.
    public static func load() throws -> AppSecrets {
        if let bundled = loadFromBundle() {
            try? seedKeychain(with: bundled)
            return bundled
        }

        if (try? Keychain.string(for: Account.seeded)) == "1",
           let id = try? Keychain.string(for: Account.clientID),
           let secret = try? Keychain.string(for: Account.clientSecret),
           let member = try? Keychain.string(for: Account.memberID),
           !id.isEmpty, !secret.isEmpty {
            return AppSecrets(clientID: id, clientSecret: secret, memberID: member)
        }

        throw AuthError.missingSecrets
    }

    /// Mirror the resolved secrets into the Keychain so plist-less builds can
    /// still read them (Approach option c — config seeds Keychain).
    private static func seedKeychain(with secrets: AppSecrets) throws {
        try Keychain.set(secrets.clientID, for: Account.clientID)
        try Keychain.set(secrets.clientSecret, for: Account.clientSecret)
        try Keychain.set(secrets.memberID, for: Account.memberID)
        try Keychain.set("1", for: Account.seeded)
    }

    /// Decode the gitignored `Secrets.plist` from the app bundle.
    private static func loadFromBundle() -> AppSecrets? {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dict = plist as? [String: Any],
            let id = dict["client_id"] as? String, !id.isEmpty,
            let secret = dict["client_secret"] as? String, !secret.isEmpty,
            let member = dict["member_id"] as? String, !member.isEmpty
        else {
            return nil
        }
        return AppSecrets(clientID: id, clientSecret: secret, memberID: member)
    }
}
