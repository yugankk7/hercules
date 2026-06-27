import SwiftUI
import PolarProtocol

/// 04 · HOME — the dashboard feed: an instrument header (date + freshness +
/// pull hint) above a scroll of all 8 cards in `CardKind.allCases` order.
/// Pull-to-refresh is the only sync trigger; no circular spinners (Norm 4).
/// Presentation only — all display data flows from the observed `DashboardModel`.
struct DashboardView: View {
    let model: DashboardModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                LazyVStack(spacing: 10) {
                    ForEach(model.cards) { card in
                        DashboardCardView(card: card)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .background(Theme.background)
        .refreshable { await model.refresh() }
        .task { await model.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TODAY")
                Spacer()
                Text(Self.dateLabel)
            }
            .font(Theme.mono(9, .semibold))
            .tracking(2)
            .foregroundStyle(Theme.muted)

            Text("DASHBOARD")
                .font(Theme.mono(22, .heavy))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)

            HStack {
                Text(freshnessLabel)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text("PULL TO SYNC")
                    .foregroundStyle(Theme.muted)
            }
            .font(Theme.mono(9, .semibold))
            .tracking(2)
        }
    }

    /// `neverSynced → "NEVER SYNCED"`; recent → `"SYNCED JUST NOW"`; otherwise a
    /// relative phrase from `RelativeDateTimeFormatter` (which itself supplies the
    /// "ago"), e.g. `"SYNCED 2 MIN. AGO"`.
    private var freshnessLabel: String {
        switch model.freshness {
        case .neverSynced:
            return "NEVER SYNCED"
        case .syncedAt(let date):
            if Date().timeIntervalSince(date) < 60 {
                return "SYNCED JUST NOW"
            }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let relative = formatter.localizedString(for: date, relativeTo: Date())
            return "SYNCED \(relative.uppercased())"
        }
    }

    private static var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE · dd MMM"
        return formatter.string(from: Date()).uppercased()
    }
}
