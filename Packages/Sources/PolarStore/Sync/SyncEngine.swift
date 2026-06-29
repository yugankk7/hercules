import Foundation
import PolarProtocol

/// The real `RefreshCoordinating`: one tap fetches every domain from the v3/v4
/// clients, persists each through the store, and reports a per-domain outcome —
/// without one domain's failure aborting the rest (HERC-051), and without
/// unbounded memory on the per-day activity path (HERC-052). Owns *orchestration
/// only*: no decoding (clients), no SQL (store), no `URLSession`/`GRDB` import
/// (Safeguard 9). Domains run sequentially by priority to avoid API hammering and
/// v4 refresh-token races (Norm 3).
public struct SyncEngine: RefreshCoordinating {
    let descriptors: [SyncDomainDescriptor]
    let store: any SyncStore
    let now: @Sendable () -> Date
    /// Days re-pulled before `lastSync` so server-side corrections to recent data
    /// are picked up; idempotent upserts absorb the overlap (HERC-054).
    let overlapDays: Int

    public init(
        descriptors: [SyncDomainDescriptor],
        store: any SyncStore,
        now: @escaping @Sendable () -> Date,
        overlapDays: Int = 2
    ) {
        self.descriptors = descriptors
        self.store = store
        self.now = now
        self.overlapDays = overlapDays
    }

    public func refresh() async throws -> SyncReport {
        let ordered = descriptors.sorted { $0.priority < $1.priority }
        var outcomes: [SyncOutcome] = []
        var anySuccess = false

        for descriptor in ordered {
            // Incremental anchor: full lookback when never synced, else the small
            // [lastSync − overlap, now] window (HERC-054). `try?` — a read failure
            // degrades to a full backfill rather than aborting the domain.
            let last = try? store.lastSync(domain: descriptor.domain.rawValue)
            let windows = invocationWindows(for: descriptor.policy, lastSync: last)

            // Each invocation isolated: a single bad sub-window/day is recorded
            // and the loop continues (HERC-051/052).
            var firstError: String?
            for window in windows {
                do {
                    try await descriptor.action(window)
                } catch {
                    if firstError == nil { firstError = Self.shortMessage(error) }
                }
            }

            if let firstError {
                outcomes.append(SyncOutcome(domain: descriptor.domain, result: .failure(firstError)))
                // Do NOT recordSync — the anchor stays at the last successful sync
                // so the next refresh re-pulls from there (no gap).
            } else {
                outcomes.append(SyncOutcome(domain: descriptor.domain, result: .success))
                anySuccess = true
                try? store.recordSync(
                    domain: descriptor.domain.rawValue,
                    window: Self.windowLabel(windows)
                )
            }
        }

        // Never throws on partial/total failure — failures live in `outcomes`.
        return SyncReport(
            freshness: anySuccess ? .syncedAt(now()) : .neverSynced,
            outcomes: outcomes
        )
    }

    /// Derive the invocation list from the policy: `[nil]` for windowless, capped
    /// sub-windows for windowed, per-day windows for perDay — each over the
    /// effective (incremental) window.
    private func invocationWindows(
        for policy: SyncWindowPolicy,
        lastSync: Date?
    ) -> [DateWindow?] {
        switch policy {
        case .windowless:
            return [nil]
        case let .windowed(lastDays, capDays):
            let window = WindowPlanner.syncWindow(
                lastSync: lastSync,
                lookbackDays: lastDays,
                overlapDays: overlapDays,
                now: now()
            )
            return WindowPlanner.split(window, capDays: capDays).map(Optional.some)
        case let .perDay(lastDays):
            let window = WindowPlanner.syncWindow(
                lastSync: lastSync,
                lookbackDays: lastDays,
                overlapDays: overlapDays,
                now: now()
            )
            return WindowPlanner.dailyWindows(window).map(Optional.some)
        }
    }

    /// `"windowless"`, or `"<from>..<to>"` (ISO date) spanning all planned windows.
    private static func windowLabel(_ windows: [DateWindow?]) -> String {
        let actual = windows.compactMap { $0 }
        guard let first = actual.first, let last = actual.last else { return "windowless" }
        return "\(PolarDateFormat.dateOnly(first.from))..\(PolarDateFormat.dateOnly(last.to))"
    }

    /// Reduce a thrown error to a short, redaction-safe message (no tokens / raw
    /// payloads — Safeguard 8). `AuthError` cases carry only codes/scopes; any
    /// other error is reported by type name only.
    private static func shortMessage(_ error: Error) -> String {
        if let authError = error as? AuthError {
            return String(describing: authError)
        }
        return String(describing: type(of: error))
    }
}
