import Foundation

/// Refresh-aware v4 transport. An `actor` so concurrent callers coordinate a
/// **single-flight** refresh: N simultaneous 401s trigger exactly one refresh,
/// and each original request retries **at most once** — no busy-loop
/// (Safeguard 2). All v4 data calls must route through this client (Safeguard 4).
public actor RefreshAwareV4Client {
    private let store: any TokenStoring
    private let oauth: any OAuthClienting
    private let config: RealmConfig
    private let session: URLSession

    /// The in-flight refresh shared by concurrent callers (single-flight).
    private var inFlightRefresh: Task<V4TokenPair, Error>?

    public init(
        store: any TokenStoring,
        oauth: any OAuthClienting,
        config: RealmConfig,
        session: URLSession = .shared
    ) {
        self.store = store
        self.oauth = oauth
        self.config = config
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        var pair = try currentPair()

        // Proactive refresh on known expiry.
        if pair.isExpired {
            pair = try await refreshIfNeeded(current: pair)
        }

        var (data, response) = try await send(request, token: pair.accessToken)

        // Reactive refresh + single retry on 401.
        if (response as? HTTPURLResponse)?.statusCode == 401 {
            let refreshed = try await refreshIfNeeded(current: pair)
            (data, response) = try await send(request, token: refreshed.accessToken)
        }

        return (data, response)
    }

    // MARK: - Internals

    private func currentPair() throws -> V4TokenPair {
        guard let pair = try store.loadV4() else { throw AuthError.refreshFailed }
        return pair
    }

    private func send(_ request: URLRequest, token: String) async throws -> (Data, URLResponse) {
        var authed = request
        authed.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            return try await session.data(for: authed)
        } catch {
            throw AuthError.network("v4 request failed")
        }
    }

    /// Single-flight refresh: concurrent callers await the same in-flight `Task`.
    /// On success the new pair is persisted; on failure `AuthError.refreshFailed`.
    private func refreshIfNeeded(current pair: V4TokenPair) async throws -> V4TokenPair {
        if let task = inFlightRefresh {
            return try await task.value
        }

        let task = Task { [oauth, config, store] in
            let refreshed = try await oauth.refresh(pair, config)
            try store.saveV4(refreshed)
            return refreshed
        }
        inFlightRefresh = task
        defer { inFlightRefresh = nil }

        do {
            let refreshed = try await task.value
            return refreshed
        } catch {
            throw AuthError.refreshFailed
        }
    }
}
