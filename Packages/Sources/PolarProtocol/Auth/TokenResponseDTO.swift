import Foundation

/// A thin `Codable` mirror of the OAuth token endpoint wire body — **not** a
/// domain type. Both realms share identical HTTP mechanics; they differ only in
/// which fields are populated, resolved here at mapping time. Tolerates optional
/// `refresh_token` / `scope` / `x_user_id`.
public struct TokenResponseDTO: Codable, Sendable {
    public let access_token: String
    public let refresh_token: String?
    public let expires_in: Int
    public let scope: String?
    public let x_user_id: String?

    private enum CodingKeys: String, CodingKey {
        case access_token, refresh_token, expires_in, scope, x_user_id
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        access_token = try c.decode(String.self, forKey: .access_token)
        refresh_token = try c.decodeIfPresent(String.self, forKey: .refresh_token)
        expires_in = try c.decodeIfPresent(Int.self, forKey: .expires_in) ?? 0
        scope = try c.decodeIfPresent(String.self, forKey: .scope)
        // `x_user_id` may arrive as a JSON string (v3) or number depending on realm.
        if let s = try? c.decodeIfPresent(String.self, forKey: .x_user_id) {
            x_user_id = s
        } else if let n = try? c.decodeIfPresent(Int.self, forKey: .x_user_id) {
            x_user_id = String(n)
        } else {
            x_user_id = nil
        }
    }

    public init(access_token: String, refresh_token: String?, expires_in: Int, scope: String?, x_user_id: String?) {
        self.access_token = access_token
        self.refresh_token = refresh_token
        self.expires_in = expires_in
        self.scope = scope
        self.x_user_id = x_user_id
    }
}

extension TokenResponseDTO {
    /// Map to a v3 credential — store the bearer, capture the AccessLink user id.
    func v3Credential() -> V3Credential {
        V3Credential(accessToken: access_token, userID: x_user_id)
    }

    /// Map to a v4 token pair. `expiresAt = now + expires_in`; granted scopes are
    /// parsed from the space-delimited `scope` echo, falling back to the requested
    /// set when absent. A missing `refresh_token` carries the prior one forward.
    func v4Pair(requestedScopes: [String], previousRefreshToken: String? = nil) -> V4TokenPair {
        let parsed = scope?.split(separator: " ").map(String.init) ?? []
        return V4TokenPair(
            accessToken: access_token,
            refreshToken: refresh_token ?? previousRefreshToken ?? "",
            expiresAt: Date().addingTimeInterval(TimeInterval(expires_in)),
            grantedScopes: parsed.isEmpty ? requestedScopes : parsed
        )
    }
}
