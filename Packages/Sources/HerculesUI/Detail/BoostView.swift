import SwiftUI
import PolarProtocol

/// 07 · BOOST FROM SLEEP — the screen behind the dashboard's BOOST card
/// (`Boost From Sleep.dc.html`). Renders the four `BoostState`s: forecast
/// (score /10 + classification, hourly boost bars, gate/window, inertia,
/// duration), provisional (an `ESTIMATE` night, flagged/dimmed), calibrating
/// ("NIGHTS LOGGED NN / 14"), and no-data ("NO DATA"). Local-first, custom
/// `GeometryReader`/`Path` bars, no spinner (Norm 4). Interactive affordances
/// ("HOW IT WORKS") are static (Scope boundary).
public struct BoostView: View {
    let model: BoostDetailModel

    @Environment(\.dismiss) private var dismiss
    @State private var p: Double = 0

    public init(model: BoostDetailModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                switch model.detail.state {
                case .forecast, .provisional: forecastBody(model.detail)
                case .calibrating: calibratingBody(model.detail)
                case .noData: noDataBody
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded(handleSwipe))
        .task { await model.load() }
        .onChange(of: model.detail.dateLabel, initial: true) { _, _ in
            p = 0
            withAnimation(.easeOut(duration: 1.1)) { p = 1 }
        }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let dx = value.translation.width, dy = value.translation.height
        guard abs(dx) > 55, abs(dx) > abs(dy) * 1.4 else { return }
        Task { dx < 0 ? await model.showOlder() : await model.showNewer() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Theme.slate, lineWidth: 1))
            }
            HStack(spacing: 12) {
                chevron("chevron.left", enabled: model.canShowOlder) { Task { await model.showOlder() } }
                VStack(spacing: 4) {
                    Text(model.detail.title)
                        .font(Theme.mono(13, .bold)).tracking(2.5).foregroundStyle(Theme.text)
                    Text(model.detail.dateLabel)
                        .font(Theme.mono(10, .medium)).tracking(1.5)
                        .foregroundStyle(Theme.text.opacity(0.42))
                }
                chevron("chevron.right", enabled: model.canShowNewer) { Task { await model.showNewer() } }
            }
            .frame(maxWidth: .infinity)
            Color.clear.frame(width: 34, height: 34)
        }
    }

    private func chevron(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted).frame(width: 16, height: 16)
        }
        .opacity(enabled ? 1 : 0).disabled(!enabled)
    }

    // MARK: - Forecast / provisional

    private func forecastBody(_ d: BoostDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            scoreBlock(d)
            hourlyBoost(d)
            metaGrid(d)
        }
        .opacity(d.state == .provisional ? 0.82 : 1)
    }

    private func scoreBlock(_ d: BoostDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BOOST").font(Theme.mono(9, .semibold)).tracking(2)
                .foregroundStyle(Theme.text.opacity(0.45))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(d.grade.map { String(format: "%.1f", $0 * p) } ?? "—")
                    .font(Theme.mono(48, .heavy)).tracking(-2)
                    .foregroundStyle(Theme.accent).monospacedDigit()
                Text("/10").font(Theme.mono(13, .bold)).foregroundStyle(Theme.muted)
                Spacer()
                if d.state == .provisional {
                    Text("ESTIMATE")
                        .font(Theme.mono(8.5, .bold)).tracking(1.5)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(Theme.cardBorder, lineWidth: 1))
                }
            }
            HStack(spacing: 8) {
                if let classification = d.classification {
                    Text(classification.label)
                        .font(Theme.mono(11, .bold)).tracking(1).foregroundStyle(Theme.text)
                }
                Text(Self.tagline(d.classification))
                    .font(Theme.mono(9, .semibold)).tracking(1).foregroundStyle(Theme.muted)
            }
        }
    }

    private func hourlyBoost(_ d: BoostDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("HOURLY BOOST").font(Theme.mono(10, .semibold)).tracking(2)
                    .foregroundStyle(Theme.text.opacity(0.45))
                Spacer()
                Text("ALERT · LOW").font(Theme.mono(8, .semibold)).tracking(1)
                    .foregroundStyle(Theme.faint)
            }
            if d.hourly.isEmpty {
                Text("NO HOURLY DATA")
                    .font(Theme.mono(9, .semibold)).tracking(1.5)
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                BoostBarsChart(bars: d.hourly)
                    .frame(height: 130)
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    private func metaGrid(_ d: BoostDetail) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible())], spacing: 11) {
            metaCell("GATE", d.gate.map { "\(Self.clock($0.lowerBound))–\(Self.clock($0.upperBound))" } ?? "—")
            metaCell("INERTIA", d.inertia?.label ?? "—")
            metaCell("DURATION", d.window.map { Self.hm($0.upperBound - $0.lowerBound) } ?? "—")
            metaCell("SLEEP BLOCK", d.window.map { "\(Self.clock($0.lowerBound)) → \(Self.clock($0.upperBound))" } ?? "—")
        }
    }

    private func metaCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(Theme.mono(8.5, .semibold)).tracking(1.5)
                .foregroundStyle(Theme.text.opacity(0.38))
            Text(value).font(Theme.mono(14, .heavy)).foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Calibrating

    private func calibratingBody(_ d: BoostDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("BOOST").font(Theme.mono(9, .semibold)).tracking(2)
                    .foregroundStyle(Theme.text.opacity(0.45))
                Text("CALIBRATING")
                    .font(Theme.mono(30, .heavy)).tracking(-1).foregroundStyle(Theme.accent)
                Text("SleepWise is learning your rhythm. Your daily Boost forecast unlocks after two weeks of nights.")
                    .font(Theme.mono(10, .medium)).foregroundStyle(Theme.text.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("NIGHTS LOGGED").font(Theme.mono(9, .semibold)).tracking(2)
                        .foregroundStyle(Theme.text.opacity(0.45))
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%02d", d.nightsLogged))
                            .font(Theme.mono(24, .heavy)).foregroundStyle(Theme.text).monospacedDigit()
                        Text("/ \(d.calibrationTarget)")
                            .font(Theme.mono(11, .bold)).foregroundStyle(Theme.muted)
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.panelDark)
                        Rectangle().fill(Theme.accent)
                            .frame(width: geo.size.width
                                   * min(CGFloat(d.nightsLogged) / CGFloat(max(d.calibrationTarget, 1)), 1) * CGFloat(p))
                    }
                }
                .frame(height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            Text("HOURLY BOOST · COLLECTING DATA")
                .font(Theme.mono(9, .semibold)).tracking(1.5).foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity, minHeight: 90)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - No data

    private var noDataBody: some View {
        VStack(spacing: 12) {
            Text("—").font(Theme.mono(34, .heavy)).foregroundStyle(Theme.faint)
            Text("NO DATA").font(Theme.mono(12, .bold)).tracking(2).foregroundStyle(Theme.muted)
            Text("Your band wasn't worn last night. Wear it to sleep to see your Boost from Sleep forecast.")
                .font(Theme.mono(10, .medium)).foregroundStyle(Theme.text.opacity(0.4))
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Text("SYNC BAND ON DASHBOARD")
                .font(Theme.mono(9, .bold)).tracking(2).foregroundStyle(Theme.accent).padding(.top, 8)
            Text("LAST 24 HOURS · UNAVAILABLE")
                .font(Theme.mono(8, .semibold)).tracking(1.5).foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity, minHeight: 340)
    }

    // MARK: - Formatting

    static func clock(_ hour: Double) -> String {
        let h24 = Int(hour.truncatingRemainder(dividingBy: 24))
        let minutes = Int((hour - Double(Int(hour))) * 60 + 0.5) % 60
        return String(format: "%02d:%02d", (h24 + 24) % 24, minutes)
    }

    /// Fractional-hour span → `"7H19M"`.
    static func hm(_ hours: Double) -> String {
        let total = Int((hours * 60).rounded())
        return "\(total / 60)H\(String(format: "%02d", total % 60))M"
    }

    static func tagline(_ classification: GradeClass?) -> String {
        switch classification {
        case .excellent: "PEAK REST, STRONG DAY AHEAD"
        case .good:      "SOLID REST, GOOD DAY AHEAD"
        case .fair:      "DECENT REST, STEADY DAY AHEAD"
        case .weak:      "LIGHT REST, PACE YOURSELF"
        default:         ""
        }
    }
}

/// Hourly boost bars, each positioned by its **own** `start`/`end` on the day's
/// span (partial edge buckets kept). `p` grows the bars up from the baseline.
private struct BoostBarsChart: View {
    let bars: [BoostBar]
    @State private var p: Double = 0

    private var lower: Double { bars.map(\.start).min() ?? 0 }
    private var upper: Double { bars.map(\.end).max() ?? 24 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let span = max(upper - lower, 0.1)
            ForEach(bars) { bar in
                let x = CGFloat((bar.start - lower) / span) * w
                let width = max(CGFloat((bar.end - bar.start) / span) * w - 1.5, 1)
                let barHeight = h * CGFloat(bar.level) / 4
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.zoneRamp[bar.level].opacity(bar.isEstimate ? 0.55 : 1))
                    .frame(width: width, height: max(barHeight * CGFloat(p), 2))
                    .position(x: x + width / 2, y: h - max(barHeight * CGFloat(p), 2) / 2)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { p = 1 } }
    }
}

#Preview {
    NavigationStack {
        BoostView(model: BoostDetailModel())
    }
}
