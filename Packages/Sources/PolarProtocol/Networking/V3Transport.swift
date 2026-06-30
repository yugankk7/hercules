import Foundation

/// Thin v3 transport: the AccessLink **v3** analogue of `RefreshAwareV4Client`,
/// **minus any refresh path** — v3 issues a single ~10-year bearer and no
/// refresh token, so there is deliberately no lifecycle code here. Mirrors the
/// established `UserRegistrationService` calling pattern: read the stored
/// `V3Credential`, attach `Bearer`, execute, map status → `AuthError`.
///
/// Never logs the Authorization header or token value (Norm 4 / Safeguard 3).
public struct V3Transport: Sendable {
    /// Fixed v3 base URL (`ARCHITECTURE.md` §7). Centralized here — never at call sites.
    private static let base = "https://www.polaraccesslink.com/v3"

    private let store: any TokenStoring
    private let session: URLSession

    public init(store: any TokenStoring, session: URLSession = .shared) {
        self.store = store
        self.session = session
    }

    /// Execute an authenticated v3 GET. Returns the raw body (empty `Data` on a
    /// `204` is a valid no-data success). A missing v3 credential maps to
    /// `AuthError.refreshFailed` (re-auth required); a non-2xx to
    /// `AuthError.httpStatus`.
    public func get(path: String, query: [URLQueryItem] = []) async throws -> Data {
        guard let cred = try store.loadV3() else { throw AuthError.refreshFailed }

        guard var comps = URLComponents(string: Self.base + path) else {
            throw AuthError.network("v3 malformed URL")
        }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw AuthError.network("v3 malformed URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(cred.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network("v3 request failed")
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            #if DEBUG
            // Surface the server's error body on failure — it carries the reason
            // (e.g. range limits) and, on a non-2xx, no secrets or user data. DEBUG-only.
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count)B>"
            print("[v3] \(path) failed: status=\(status) body=\(body)")
            #else
            print("[v3] \(path) failed: status=\(status)")
            #endif
            throw AuthError.httpStatus(status)
        }
        return data
    }
}
