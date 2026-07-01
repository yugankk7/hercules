import Foundation

/// The shared sync vocabulary referenced by the refresh protocol, the engine
/// (`PolarStore`), and the dashboard view-model (`HerculesUI`). These value types
/// live in `PolarProtocol` — the seam both sides already depend on — so the engine
/// and UI can speak `SyncOutcome`/`SyncReport` without `HerculesUI` importing
/// `PolarStore`. Per-domain status is carried in `SyncReport`, never persisted
/// (Safeguard 9 — no `sync_state` error column).

/// One syncable metric. The `rawValue` is the `sync_state.domain` key the store
/// reads/writes via `lastSync(domain:)` / `recordSync(domain:window:)`.
public enum SyncDomain: String, Sendable, CaseIterable, Equatable {
    case sleep
    /// SleepWise (Boost From Sleep): alertness + circadian-bedtime, merged per
    /// night. Additive — feeds `freshness()` (`max` over domains) and `SyncReport`
    /// with no exhaustive switch to break (Safeguard 9).
    case sleepwise
    case recharge
    case cardioLoad
    case continuousHR
    case activity
    case trainingSessions
    case sports
    case devices
}

/// Sync ordering: lower runs first. `Comparable` on the raw `Int` so the engine
/// can `sort(by:)` descriptors by priority (HERC-051).
public enum SyncPriority: Int, Sendable, Comparable {
    case p0
    case p1
    case p2

    public static func < (lhs: SyncPriority, rhs: SyncPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Outcome of a single domain's sync. `failure` carries a short, redaction-safe
/// message (no tokens / raw payloads — Safeguard 8).
public enum SyncDomainResult: Sendable, Equatable {
    case success
    case failure(String)
}

/// A domain paired with how its sync went, for the per-domain report (HERC-051).
public struct SyncOutcome: Sendable, Equatable {
    public let domain: SyncDomain
    public let result: SyncDomainResult

    public init(domain: SyncDomain, result: SyncDomainResult) {
        self.domain = domain
        self.result = result
    }
}

/// The result of one `refresh()`: an aggregate freshness plus every domain's
/// outcome. `refresh()` returns this even on partial/total failure — failures
/// live in `outcomes`, never thrown (Safeguard 2).
public struct SyncReport: Sendable, Equatable {
    public let freshness: SyncFreshness
    public let outcomes: [SyncOutcome]

    public init(freshness: SyncFreshness, outcomes: [SyncOutcome]) {
        self.freshness = freshness
        self.outcomes = outcomes
    }
}
