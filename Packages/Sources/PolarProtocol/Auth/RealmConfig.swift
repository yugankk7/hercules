import Foundation

/// Per-realm OAuth configuration: authorize/token endpoints, the shared client
/// credentials, redirect URI, and requested scopes. All endpoint strings are
/// centralized here — never scattered across call sites (Norm 5).
public struct RealmConfig: Sendable {
    public let realm: AuthRealm
    public let authorizeEndpoint: URL
    public let tokenEndpoint: URL
    public let clientID: String
    public let clientSecret: String
    public let redirectURI: String
    public let scopes: [String]

    public init(
        realm: AuthRealm,
        authorizeEndpoint: URL,
        tokenEndpoint: URL,
        clientID: String,
        clientSecret: String,
        redirectURI: String,
        scopes: [String]
    ) {
        self.realm = realm
        self.authorizeEndpoint = authorizeEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.scopes = scopes
    }

    /// The custom URL scheme of `redirectURI` (e.g. `hercules`), used as the
    /// `ASWebAuthenticationSession` callback scheme.
    public var callbackScheme: String {
        URLComponents(string: redirectURI)?.scheme ?? "hercules"
    }

    /// Compose the authorize URL: `response_type=code`, `client_id`,
    /// `redirect_uri`, space-joined `scope`, and the CSRF `state` nonce.
    public func authorizeURL(state: String) -> URL {
        guard var comps = URLComponents(url: authorizeEndpoint, resolvingAgainstBaseURL: false) else {
            return authorizeEndpoint
        }
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
        ]
        return comps.url ?? authorizeEndpoint
    }
}

public extension RealmConfig {
    /// Custom-scheme redirect, confirmed accepted by Polar (live debug 2026-06-26).
    /// The exchange `redirect_uri` MUST byte-match this authorize value.
    static let redirectURI = "hercules://oauth/callback"

    /// v3 scope — read-all AccessLink.
    static let v3Scopes = ["accesslink.read_all"]

    /// The 12 verified-grantable v4 scopes (live debug 2026-06-26).
    static let v4Scopes = [
        "activity:read",
        "calendar:read",
        "continuous_samples:read",
        "devices:read",
        "nightly_recharge:read",
        "ppi_data:read",
        "routes:read",
        "skin_contact:read",
        "sleep:read",
        "sports:read",
        "training_sessions:read",
        "training_targets:read",
    ]

    /// v3 realm — `flow.polar.com` authorize, `polarremote.com/v2` token.
    static func v3(secrets: AppSecrets) -> RealmConfig {
        RealmConfig(
            realm: .v3,
            authorizeEndpoint: URL(string: "https://flow.polar.com/oauth2/authorization")!,
            tokenEndpoint: URL(string: "https://polarremote.com/v2/oauth2/token")!,
            clientID: secrets.clientID,
            clientSecret: secrets.clientSecret,
            redirectURI: redirectURI,
            scopes: v3Scopes
        )
    }

    /// v4 realm — `auth.polar.com` authorize + token.
    static func v4(secrets: AppSecrets) -> RealmConfig {
        RealmConfig(
            realm: .v4,
            authorizeEndpoint: URL(string: "https://auth.polar.com/oauth/authorize")!,
            tokenEndpoint: URL(string: "https://auth.polar.com/oauth/token")!,
            clientID: secrets.clientID,
            clientSecret: secrets.clientSecret,
            redirectURI: redirectURI,
            scopes: v4Scopes
        )
    }
}
