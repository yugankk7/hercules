import Foundation

/// Reads the current dashboard feed. Local-first and **non-throwing**: a real
/// `PolarStore`-backed provider (HERC-042) returns instantly from the local
/// store — empty when no data exists. The seam lives in `PolarProtocol` so that
/// future provider can conform without a UI dependency. Mirrors
/// `InitialSyncProviding` from the auth slice.
public protocol DashboardProviding: Sendable {
    /// Read the current feed snapshot. Returns instantly; no network this slice.
    func snapshot() async -> DashboardSnapshot
}

/// Returns all 8 cards in `.empty` state with `.neverSynced` freshness — the
/// first-run shell, which is the primary visual this slice. Replaced by the
/// `PolarStore`-backed provider in HERC-042.
public struct StubDashboardProvider: DashboardProviding {
    public init() {}

    public func snapshot() async -> DashboardSnapshot {
        DashboardSnapshot(
            cards: CardKind.allCases.map { DashboardCard(kind: $0, state: .empty) },
            freshness: .neverSynced
        )
    }
}
