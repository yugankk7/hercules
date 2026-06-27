import Foundation

/// One row in the home feed, typed by `CardKind` and rendered per `CardState`.
/// `headline`/`detail` stay `nil` this slice — populated rendering arrives with
/// each domain's own feature, so no per-domain fields are added here (Data
/// constraint, Safeguard 8). `Identifiable` by `kind`.
public struct DashboardCard: Sendable, Identifiable, Equatable {
    public let kind: CardKind
    public let state: CardState
    public let headline: String?
    public let detail: String?

    public var id: CardKind { kind }

    public init(
        kind: CardKind,
        state: CardState,
        headline: String? = nil,
        detail: String? = nil
    ) {
        self.kind = kind
        self.state = state
        self.headline = headline
        self.detail = detail
    }
}
