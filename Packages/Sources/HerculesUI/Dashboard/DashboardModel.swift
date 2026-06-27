import Foundation
import Observation
import PolarProtocol

/// Home-feed view-model. Mirrors `AuthManager`: `@MainActor @Observable`, seam
/// protocols injected via initializer with stub live defaults, state exposed
/// `private(set)`. No SwiftUI import — display logic lives in the views.
@MainActor
@Observable
public final class DashboardModel {

    public private(set) var cards: [DashboardCard] = []
    public private(set) var freshness: SyncFreshness = .neverSynced
    public private(set) var isRefreshing = false
    public private(set) var lastRefreshFailed = false

    private let provider: any DashboardProviding
    private let coordinator: any RefreshCoordinating

    public init(
        provider: any DashboardProviding = StubDashboardProvider(),
        coordinator: any RefreshCoordinating = StubRefreshCoordinator()
    ) {
        self.provider = provider
        self.coordinator = coordinator
    }

    /// Pull the current snapshot on appear (local-first; instant).
    public func load() async {
        let snapshot = await provider.snapshot()
        cards = snapshot.cards
        freshness = snapshot.freshness
    }

    /// Pull-to-refresh. Guards re-entrancy, runs the coordinator (no network in
    /// the stub), then re-pulls the cards while keeping the just-set freshness.
    /// A thrown error is non-fatal: it records `lastRefreshFailed` and preserves
    /// the prior freshness (Approach 7 / Safeguard 6) — no banner this slice.
    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            freshness = try await coordinator.refresh()
            lastRefreshFailed = false
        } catch {
            lastRefreshFailed = true
        }
        cards = await provider.snapshot().cards
    }

    /// Routing seam — **no-op this slice**. Push the detail screen for `card`
    /// when detail screens land (EPIC 6/7).
    public func select(_ card: DashboardCard) {
        // No-op: detail navigation is not part of this slice.
    }
}
