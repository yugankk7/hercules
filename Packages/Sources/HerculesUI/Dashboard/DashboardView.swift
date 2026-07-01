import SwiftUI
import PolarProtocol

/// 04 · HOME — the dashboard feed: an instrument header (date + freshness +
/// pull hint) above a scroll of all 8 cards in `CardKind.allCases` order.
/// Pull-to-refresh is the only sync trigger; no circular spinners (Norm 4).
/// Presentation only — all display data flows from the observed `DashboardModel`.
struct DashboardView: View {
    let model: DashboardModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    LazyVStack(spacing: 10) {
                        ForEach(model.cards) { card in
                            if model.hasDetail(for: card.kind) {
                                NavigationLink(value: card.kind) {
                                    DashboardCardView(card: card)
                                }
                                .buttonStyle(.plain)
                            } else {
                                DashboardCardView(card: card)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
            .background(Theme.background)
            .refreshable { await model.refresh() }
            .task { await model.load() }
            .navigationDestination(for: CardKind.self) { kind in
                switch model.detailModel(for: kind) {
                case .activity(let detail): ActivityDetailView(model: detail)
                case .sleep(let detail): SleepDetailView(model: detail)
                case .boost(let detail): BoostView(model: detail)
                case .none: EmptyView()
                }
            }
        }
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
                Text(model.isRefreshing ? "SYNCING" : freshnessLabel)
                    .foregroundStyle(Theme.accent)
                Spacer()
                if model.isRefreshing {
                    SyncIndicator()
                } else {
                    Text("PULL TO SYNC")
                        .foregroundStyle(Theme.muted)
                }
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

/// A small in-scheme sync loader: three accent dots pulsing in sequence — the
/// instrument-panel analogue of a spinner (Norm 4: no circular spinners). Shown
/// in the dashboard header while `DashboardModel.isRefreshing`.
private struct SyncIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 4, height: 4)
                    .opacity(opacity(for: i))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
        .accessibilityLabel("Syncing")
    }

    /// Each dot leads the next by one slot, so the lit dot walks left→right.
    private func opacity(for index: Int) -> Double {
        let distance = (phase - Double(index)).truncatingRemainder(dividingBy: 3)
        let wrapped = distance < 0 ? distance + 3 : distance
        return 0.25 + 0.75 * max(0, 1 - wrapped)
    }
}
