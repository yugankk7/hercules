import Foundation

/// An immutable read of the whole feed: the ordered cards plus how fresh they
/// are. Returned by `DashboardProviding.snapshot()`.
public struct DashboardSnapshot: Sendable {
    public let cards: [DashboardCard]
    public let freshness: SyncFreshness

    public init(cards: [DashboardCard], freshness: SyncFreshness) {
        self.cards = cards
        self.freshness = freshness
    }
}
