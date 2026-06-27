import SwiftUI
import PolarProtocol

/// Renders a single `DashboardCard` as a slate card matching `ConsentView`'s
/// `ScopeRow`: a 34pt glyph tile + tracked mono title, with a state-driven body.
/// **Non-interactive** this slice (no `Button`/tap gesture) — presentation only;
/// the routing seam is `DashboardModel.select(_:)`.
struct DashboardCardView: View {
    let card: DashboardCard

    var body: some View {
        HStack(spacing: 14) {
            Text(card.kind.glyph)
                .font(Theme.mono(15, .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.slate, in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(card.kind.title)
                    .font(Theme.mono(12, .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.text)
                stateBody
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
    }

    /// Absence of data is the designed first-run state — a muted `—` hero with a
    /// `NO DATA YET` sublabel. Populated/stale/calibrating cards surface whatever
    /// `headline`/`detail` the provider supplies (future feature slices).
    @ViewBuilder
    private var stateBody: some View {
        switch card.state {
        case .empty, .noData:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("—")
                    .font(Theme.mono(17, .heavy))
                    .foregroundStyle(Theme.muted)
                Text("NO DATA YET")
                    .font(Theme.mono(9.5, .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.faint)
            }
        case .populated, .stale, .calibrating:
            VStack(alignment: .leading, spacing: 2) {
                if let headline = card.headline {
                    Text(headline)
                        .font(Theme.mono(13, .bold))
                        .foregroundStyle(Theme.text)
                }
                if let detail = card.detail {
                    Text(detail)
                        .font(Theme.mono(10.5, .medium))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }
}
