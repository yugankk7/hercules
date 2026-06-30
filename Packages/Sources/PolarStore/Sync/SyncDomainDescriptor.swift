import Foundation
import PolarProtocol

/// How a domain's fetch window is shaped. The orchestrator stays generic; this
/// policy is the only place heterogeneity (windowless vs windowed vs per-day)
/// lives, so the engine never special-cases a domain.
public enum SyncWindowPolicy: Sendable {
    /// Server-bounded set — fetch with no window (the action ignores `nil`).
    case windowless
    /// Ranged fetch with a first-sync lookback and an API max-range cap (paged
    /// by `WindowPlanner.split`).
    case windowed(lastDays: Int, capDays: Int)
    /// Day-by-day fetch across the window (the heavy activity path — HERC-052).
    case perDay(lastDays: Int)
}

/// One declarative sync unit: a domain's identity, priority, window policy, and
/// the closure that actually fetches + upserts for a given window. The descriptor
/// holds no client/store reference itself — those are captured inside `action`
/// by `SyncRegistry` (the single config site).
public struct SyncDomainDescriptor: Sendable {
    public let domain: SyncDomain
    public let priority: SyncPriority
    public let policy: SyncWindowPolicy
    /// Fetch + upsert for one invocation. `windowless` domains receive `nil`;
    /// windowed/per-day domains receive each planned sub-window.
    public let action: @Sendable (DateWindow?) async throws -> Void

    public init(
        domain: SyncDomain,
        priority: SyncPriority,
        policy: SyncWindowPolicy,
        action: @escaping @Sendable (DateWindow?) async throws -> Void
    ) {
        self.domain = domain
        self.priority = priority
        self.policy = policy
        self.action = action
    }
}
