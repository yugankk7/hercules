import Foundation

/// Drives pull-to-refresh. `throws` is reserved for a total transport failure;
/// partial (per-domain) failure is reported inside `SyncReport.outcomes`, not
/// thrown (HERC-051). Pull-to-refresh is the only network trigger (Safeguard 7).
/// The real conformer is `SyncEngine` (PolarStore); this stub stays for
/// previews/tests.
public protocol RefreshCoordinating: Sendable {
    /// Run a refresh and report aggregate freshness + per-domain outcomes.
    func refresh() async throws -> SyncReport
}

/// Animates the refresh affordance with a short delay and reports a fresh
/// timestamp with no outcomes. Performs **no network I/O**. The real engine
/// (`SyncEngine`) replaces it at the composition root in EPIC 5.
public struct StubRefreshCoordinator: RefreshCoordinating {
    public init() {}

    public func refresh() async throws -> SyncReport {
        try await Task.sleep(for: .milliseconds(600))
        return SyncReport(freshness: .syncedAt(Date()), outcomes: [])
    }
}
