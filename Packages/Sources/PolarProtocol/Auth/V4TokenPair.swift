import Foundation

/// A short-lived v4 access token (1 h) paired with a refresh token (~100 d) and
/// the set of scopes actually granted in the consent round. `expiresAt` is
/// computed from `expires_in` at exchange time.
public struct V4TokenPair: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date
    public var grantedScopes: [String]

    /// `true` once the access token's lifetime has elapsed.
    public var isExpired: Bool { Date() >= expiresAt }

    public init(accessToken: String, refreshToken: String, expiresAt: Date, grantedScopes: [String]) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.grantedScopes = grantedScopes
    }
}
