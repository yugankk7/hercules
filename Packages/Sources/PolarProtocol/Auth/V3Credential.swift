import Foundation

/// A single long-lived (~10 yr) v3 AccessLink bearer. **No refresh token** — v3
/// issues none, so there is deliberately no refresh code path. `userID` is the
/// numeric AccessLink user id (`x_user_id`) reused by registration + data calls.
public struct V3Credential: Codable, Sendable, Equatable {
    public var accessToken: String
    public var userID: String?

    public init(accessToken: String, userID: String? = nil) {
        self.accessToken = accessToken
        self.userID = userID
    }
}
