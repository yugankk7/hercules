import SwiftUI
import PolarProtocol

/// 05 · DAILY ACTIVITY DETAIL — the screen behind the dashboard's Daily Activity
/// card (`Daily Activity.dc.html`). Custom instrument header, intensity-zone
/// breakdown, a toggleable signature viz (linear HR curve ⇄ 24h clock), daily-goal
/// bar, primary stat grid, and secondary stat rows. Local-first: opens instantly
/// from the store, numbers count up, bars draw in.
public struct ActivityDetailView: View {
    let model: ActivityDetailModel

    @Environment(\.dismiss) private var dismiss
    @State private var p: Double = 0          // count-up / bar-grow progress
    @State private var mode: VizMode = .linear

    private enum VizMode { case linear, clock }

    public init(model: ActivityDetailModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            if let detail = model.detail {
                VStack(alignment: .leading, spacing: 20) {
                    header(detail)
                    zoneBreakdown(detail)
                    vizSection(detail)
                    goal(detail)
                    statGrid(detail)
                    secondaryRows(detail)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            } else {
                emptyState
            }
        }
        .background(Theme.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onEnded(handleSwipe)
        )
        .task { await model.load() }
        // Re-run the count-ups / bar draw-in on first appearance and each day change.
        .onChange(of: model.detail?.dateLabel, initial: true) { _, _ in
            p = 0
            withAnimation(.easeOut(duration: 1.1)) { p = 1 }
        }
    }

    /// A horizontal-dominant swipe steps between days: left → older, right → newer
    /// (matching the design's day gesture).
    private func handleSwipe(_ value: DragGesture.Value) {
        let dx = value.translation.width, dy = value.translation.height
        guard abs(dx) > 55, abs(dx) > abs(dy) * 1.4 else { return }
        Task { dx < 0 ? await model.showOlder() : await model.showNewer() }
    }

    private func dayChevron(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 16, height: 16)
        }
        .opacity(enabled ? 1 : 0)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "chevron.left" ? "Previous day" : "Next day")
    }

    // MARK: - Header

    private func header(_ d: ActivityDetail) -> some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Theme.slate, lineWidth: 1))
            }
            HStack(spacing: 12) {
                dayChevron("chevron.left", enabled: model.canShowOlder) {
                    Task { await model.showOlder() }
                }
                VStack(spacing: 4) {
                    Text(d.title)
                        .font(Theme.mono(13, .bold)).tracking(2.5)
                        .foregroundStyle(Theme.text)
                    Text(d.dateLabel)
                        .font(Theme.mono(10, .medium)).tracking(1.5)
                        .foregroundStyle(Theme.text.opacity(0.42))
                }
                dayChevron("chevron.right", enabled: model.canShowNewer) {
                    Task { await model.showNewer() }
                }
            }
            .frame(maxWidth: .infinity)
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    mode = mode == .linear ? .clock : .linear
                }
            } label: {
                Image(systemName: mode == .linear ? "clock" : "waveform.path.ecg")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Theme.slate, lineWidth: 1))
            }
        }
    }

    // MARK: - Intensity zones

    private func zoneBreakdown(_ d: ActivityDetail) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("INTENSITY ZONES")
                    .font(Theme.mono(10, .semibold)).tracking(2)
                    .foregroundStyle(Theme.text.opacity(0.45))
                Spacer()
                Text("\(Self.hm(d.awakeMinutes)) AWAKE")
                    .font(Theme.mono(9, .semibold)).tracking(1)
                    .foregroundStyle(Theme.muted)
            }
            zoneBar(d)
            HStack(spacing: 0) {
                ForEach(Array(d.zones.enumerated()), id: \.offset) { i, z in
                    VStack(spacing: 5) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.zoneRamp[z.level])
                                .frame(width: 7, height: 7)
                            Text(z.name)
                                .font(Theme.mono(8, .semibold))
                                .foregroundStyle(Theme.text.opacity(0.4))
                        }
                        Text(Self.hm(z.minutes))
                            .font(Theme.mono(9.5, .bold))
                            .foregroundStyle(z.level >= 3 ? Theme.text : Theme.text.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        if i < d.zones.count - 1 {
                            Rectangle().fill(Theme.hairline).frame(width: 1, height: 22)
                        }
                    }
                }
            }
        }
    }

    private func zoneBar(_ d: ActivityDetail) -> some View {
        let nonzero = d.zones.filter { $0.minutes > 0 }
        let total = max(nonzero.reduce(0) { $0 + $1.minutes }, 1)
        return GeometryReader { geo in
            let gaps = CGFloat(max(nonzero.count - 1, 0)) * 2
            let avail = max(geo.size.width - gaps, 0)
            HStack(spacing: 2) {
                ForEach(nonzero) { z in
                    Theme.zoneRamp[z.level]
                        .frame(width: avail * CGFloat(z.minutes) / CGFloat(total))
                }
            }
            .scaleEffect(x: p, anchor: .leading)
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    // MARK: - Signature viz

    private func vizSection(_ d: ActivityDetail) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            Group {
                switch mode {
                case .linear: ActivityHRChart(detail: d)
                case .clock:  ActivityClockChart(detail: d, nowHour: Self.nowHour)
                }
            }
            .id("\(mode == .linear ? "lin" : "clk")-\(d.dateLabel)")
            .padding(.top, 18)
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .top)
        }
    }

    // MARK: - Daily goal

    private func goal(_ d: ActivityDetail) -> some View {
        let pct = Int((Double(d.dailyActivityPct) * p).rounded())
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("DAILY GOAL")
                    .font(Theme.mono(10, .semibold)).tracking(2)
                    .foregroundStyle(Theme.text.opacity(0.45))
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(pct)")
                        .font(Theme.mono(22, .heavy)).tracking(-1)
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                    Text("%").font(Theme.mono(11, .bold)).foregroundStyle(Theme.muted)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.panelDark)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.hairline, lineWidth: 1))
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * min(CGFloat(pct) / 100, 1))
                    // 100% target marker
                    Rectangle()
                        .fill(Theme.text.opacity(0.18))
                        .frame(width: 1)
                        .offset(x: geo.size.width * 0.833)
                }
            }
            .frame(height: 12)
            Text(d.dailyActivityPct >= 100
                 ? "TARGET EXCEEDED · \(d.dailyActivityPct - 100)% OVER"
                 : "ON TRACK · \(100 - d.dailyActivityPct)% TO GO")
                .font(Theme.mono(9, .semibold)).tracking(1)
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: - Primary stat grid

    private func statGrid(_ d: ActivityDetail) -> some View {
        let cells: [(String, String, String, String)] = [
            ("figure.walk", "STEPS", Self.int(Double(d.steps) * p), ""),
            ("point.topleft.down.to.point.bottomright.curvepath", "DISTANCE",
             String(format: "%.2f", d.distanceKm * p), "km"),
            ("flame", "ACTIVE TIME", Self.hm(Int(Double(d.activeMinutes) * p)), ""),
            ("bolt.heart", "CALORIES", Self.int(Double(d.calories) * p), "kcal"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible())], spacing: 11) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Image(systemName: cell.0)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 30, height: 30, alignment: .leading)
                        Spacer()
                        Text(cell.1)
                            .font(Theme.mono(8.5, .semibold)).tracking(1.5)
                            .foregroundStyle(Theme.text.opacity(0.38))
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(cell.2)
                            .font(Theme.mono(27, .heavy)).tracking(-1.5)
                            .foregroundStyle(Theme.text)
                            .monospacedDigit()
                        Text(cell.3)
                            .font(Theme.mono(11, .semibold)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 15, trailing: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.cardBorder, lineWidth: 1))
            }
        }
    }

    // MARK: - Secondary rows

    private func secondaryRows(_ d: ActivityDetail) -> some View {
        VStack(spacing: 11) {
            statRow(icon: "exclamationmark.triangle", label: "INACTIVITY STAMPS",
                    sub: "Prompts to move", trailing: "\(d.inactivityCount)", accentTrailing: true)
            statRow(icon: "moon", label: "NIGHT SLEEP",
                    sub: "Carried into today", trailing: "—", accentTrailing: false)
        }
    }

    private func statRow(icon: String, label: String, sub: String,
                         trailing: String, accentTrailing: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(accentTrailing ? Theme.accent : Theme.muted)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(Theme.mono(8.5, .semibold)).tracking(1.5)
                    .foregroundStyle(Theme.text.opacity(0.38))
                Text(sub)
                    .font(Theme.mono(11, .medium))
                    .foregroundStyle(Theme.text.opacity(0.5))
            }
            Spacer()
            Text(trailing)
                .font(Theme.mono(22, .heavy)).tracking(-1)
                .foregroundStyle(accentTrailing ? Theme.accent : Theme.text)
                .monospacedDigit()
        }
        .padding(.vertical, 14).padding(.horizontal, 18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("—").font(Theme.mono(34, .heavy)).foregroundStyle(Theme.faint)
            Text("NO ACTIVITY YET")
                .font(Theme.mono(10, .semibold)).tracking(2)
                .foregroundStyle(Theme.muted)
            Button("BACK") { dismiss() }
                .font(Theme.mono(10, .bold)).tracking(2)
                .foregroundStyle(Theme.accent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    // MARK: - Formatting

    private static func int(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: Int(value.rounded()))) ?? "\(Int(value))"
    }

    /// Minutes → `"1H23M"` (always two-digit minutes).
    private static func hm(_ minutes: Int) -> String {
        "\(minutes / 60)H\(String(format: "%02d", minutes % 60))M"
    }

    private static var nowHour: Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f
    }()
}

#Preview {
    NavigationStack {
        ActivityDetailView(model: ActivityDetailModel())
    }
}
