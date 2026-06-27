import Foundation

/// Authorize → exchange → refresh contract for a single realm.
public protocol OAuthClienting: Sendable {
    /// Drive the secure hand-off and return the authorization `code`.
    func authorize(_ cfg: RealmConfig) async throws -> String
    /// Exchange an authorization `code` for tokens (identical mechanics per realm).
    func exchange(code: String, _ cfg: RealmConfig) async throws -> TokenResponseDTO
    /// Exchange a v4 refresh token for a fresh access+refresh pair.
    func refresh(_ pair: V4TokenPair, _ cfg: RealmConfig) async throws -> V4TokenPair
}

/// `URLSession`-backed `OAuthClienting`. **Identical HTTP mechanics for both
/// realms** — Basic-auth header + form auth-code grant; realms differ only in
/// response shape, resolved at mapping time. Never logs Authorization headers,
/// codes, or token bodies (Norm 4).
public struct OAuthClient: OAuthClienting {
    private let web: any WebAuthPresenting
    private let session: URLSession

    public init(web: any WebAuthPresenting, session: URLSession = .shared) {
        self.web = web
        self.session = session
    }

    public func authorize(_ cfg: RealmConfig) async throws -> String {
        let state = UUID().uuidString
        let authorizeURL = cfg.authorizeURL(state: state)
        let callback = try await web.authenticate(url: authorizeURL, callbackScheme: cfg.callbackScheme)

        guard let comps = URLComponents(url: callback, resolvingAgainstBaseURL: false) else {
            throw AuthError.network("malformed callback URL")
        }
        let items = comps.queryItems ?? []

        if let err = items.first(where: { $0.name == "error" })?.value {
            print("[Auth] \(cfg.realm) authorize denied: \(err)")
            throw err == "access_denied" ? AuthError.cancelled : AuthError.scopeDenied([])
        }
        // CSRF: the returned state must match the nonce we issued.
        guard items.first(where: { $0.name == "state" })?.value == state else {
            throw AuthError.network("state mismatch")
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw AuthError.network("missing authorization code")
        }
        return code
    }

    public func exchange(code: String, _ cfg: RealmConfig) async throws -> TokenResponseDTO {
        try await postForm(
            [
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": cfg.redirectURI,
            ],
            cfg: cfg
        )
    }

    public func refresh(_ pair: V4TokenPair, _ cfg: RealmConfig) async throws -> V4TokenPair {
        do {
            let dto = try await postForm(
                [
                    "grant_type": "refresh_token",
                    "refresh_token": pair.refreshToken,
                ],
                cfg: cfg
            )
            return dto.v4Pair(requestedScopes: cfg.scopes, previousRefreshToken: pair.refreshToken)
        } catch {
            throw AuthError.refreshFailed
        }
    }

    // MARK: - Transport

    private func postForm(_ fields: [String: String], cfg: RealmConfig) async throws -> TokenResponseDTO {
        var request = URLRequest(url: cfg.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let basic = Data("\(cfg.clientID):\(cfg.clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        request.httpBody = Self.encodeForm(fields)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network("token endpoint request failed")
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            print("[Auth] \(cfg.realm) token exchange failed: status=\(status)")
            throw AuthError.tokenExchangeFailed(status)
        }

        do {
            return try JSONDecoder().decode(TokenResponseDTO.self, from: data)
        } catch {
            throw AuthError.network("token response decode failed")
        }
    }

    private static func encodeForm(_ fields: [String: String]) -> Data {
        var comps = URLComponents()
        comps.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        // application/x-www-form-urlencoded expects '+' for spaces in values.
        let encoded = (comps.percentEncodedQuery ?? "").replacingOccurrences(of: "%20", with: "+")
        return Data(encoded.utf8)
    }
}
