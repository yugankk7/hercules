import Foundation

/// Drives pull-to-refresh. `throws` is reserved for the future sync engine's
/// partial-failure path (HERC-051); the stub never fails. Pull-to-refresh is the
/// only network trigger (Safeguard 5) — a no-op here.
public protocol RefreshCoordinating: Sendable {
    /// Run a refresh and report the resulting freshness. **No network** in the stub.
    func refresh() async throws -> SyncFreshness
}

/// Animates the refresh affordance with a short delay and reports a fresh
/// timestamp. Performs **no network I/O**. Replaced by the real engine in EPIC 5.
public struct StubRefreshCoordinator: RefreshCoordinating {
    public init() {}

    public func refresh() async throws -> SyncFreshness {
        try await Task.sleep(for: .milliseconds(600))
        return .syncedAt(Date())
    }
}
