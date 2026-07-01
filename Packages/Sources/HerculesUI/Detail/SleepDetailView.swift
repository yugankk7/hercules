import SwiftUI
import PolarProtocol

/// 06 · SLEEP DETAIL — the screen behind the dashboard's SLEEP card
/// (`Sleep Detail.dc.html`). A DAY/WK toggle drives two subviews: DAY (score,
/// hypnogram·cycles band, HR line, amount/solidity/regen breakdown) and WEEK
/// (sleep matrix, trend, weekly consolidation). Local-first: opens instantly from
/// the store, numbers count up, bars draw in (Norm 4 — no circular spinner).
/// Reuses `Theme` tokens and the `ActivityHRChart` `GeometryReader`/`Canvas`/`Path`
/// idioms.
public struct SleepDetailView: View {
    let model: SleepDetailModel

    @Environment(\.dismiss) private var dismiss
    @State private var p: Double = 0   // count-up / draw-in progress

    public init(model: SleepDetailModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                modeToggle
                if model.mode == .day {
                    if let detail = model.detail, !detail.isEmpty {
                        dayView(detail)
                    } else {
                        emptyState
                    }
                } else {
                    weekView(model.week)
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
        .onChange(of: animationKey, initial: true) { _, _ in
            p = 0
            withAnimation(.easeOut(duration: 1.1)) { p = 1 }
        }
    }

    /// Re-triggers the draw-in on night change and on DAY↔WK switch.
    private var animationKey: String {
        "\(model.mode == .day ? "d" : "w")-\(model.detail?.dateLabel ?? "")"
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let dx = value.translation.width, dy = value.translation.height
        guard abs(dx) > 55, abs(dx) > abs(dy) * 1.4 else { return }
        Task { dx < 0 ? await model.showOlder() : await model.showNewer() }
    }

    // MARK: - Header + mode toggle

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
                dayChevron("chevron.left", enabled: model.canShowOlder) {
                    Task { await model.showOlder() }
                }
                VStack(spacing: 4) {
                    Text(model.mode == .day ? (model.detail?.title ?? "SLEEP") : "THIS WEEK")
                        .font(Theme.mono(13, .bold)).tracking(2.5)
                        .foregroundStyle(Theme.text)
                    Text(model.mode == .day
                         ? (model.detail?.dateLabel ?? "")
                         : (model.week?.rangeLabel ?? ""))
                        .font(Theme.mono(10, .medium)).tracking(1.5)
                        .foregroundStyle(Theme.text.opacity(0.42))
                }
                dayChevron("chevron.right", enabled: model.canShowNewer) {
                    Task { await model.showNewer() }
                }
            }
            .frame(maxWidth: .infinity)
            // Balance the leading back button so the title stays centred.
            Color.clear.frame(width: 34, height: 34)
        }
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
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            segment("DAY", active: model.mode == .day) { model.setMode(.day) }
            segment("WK", active: model.mode == .week) { model.setMode(.week) }
        }
        .padding(3)
        .background(Theme.panelDark, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.hairline, lineWidth: 1))
        .frame(maxWidth: 160)
        .frame(maxWidth: .infinity)
    }

    private func segment(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(10, .bold)).tracking(2)
                .foregroundStyle(active ? Color.black : Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(active ? Theme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day view

    private func dayView(_ d: SleepDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            scoreHeader(d)
            SleepHypnogramChart(detail: d)
            stageBreakdown(d)
        }
    }

    private func scoreHeader(_ d: SleepDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SLEEP SCORE")
                        .font(Theme.mono(9, .semibold)).tracking(2)
                        .foregroundStyle(Theme.text.opacity(0.45))
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(d.score.map { "\(Int(Double($0) * p))" } ?? "—")
                            .font(Theme.mono(44, .heavy)).tracking(-2)
                            .foregroundStyle(Theme.accent).monospacedDigit()
                        Text("/100").font(Theme.mono(12, .bold)).foregroundStyle(Theme.muted)
                    }
                    Text(d.amount.caption)
                        .font(Theme.mono(9, .semibold)).tracking(1.5)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(Self.clock(d.window.lowerBound))
                        .font(Theme.mono(13, .bold)).foregroundStyle(Theme.text)
                    Text(Self.clock(d.window.upperBound))
                        .font(Theme.mono(13, .bold)).foregroundStyle(Theme.text.opacity(0.6))
                    Text("\(d.cycles) CYCLES")
                        .font(Theme.mono(8.5, .semibold)).tracking(1.5)
                        .foregroundStyle(Theme.faint)
                }
            }
            HStack(spacing: 8) {
                miniChip("AMOUNT", d.amount == .below ? "LOW" : d.amount == .above ? "HIGH" : "MOD")
                miniChip("SOLIDITY", Self.solidityWord(d.continuityClass))
                miniChip("REGEN", Self.regenWord(d.stages))
            }
        }
    }

    private func miniChip(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(Theme.mono(8, .semibold)).tracking(1.5)
                .foregroundStyle(Theme.text.opacity(0.4))
            Text(value).font(Theme.mono(10.5, .bold)).foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Metric breakdown

    private func stageBreakdown(_ d: SleepDetail) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("METRIC BREAKDOWN")
                .font(Theme.mono(10, .semibold)).tracking(2)
                .foregroundStyle(Theme.text.opacity(0.45))
            metricRow(icon: "bed.double", label: "SLEEP AMOUNT",
                      sub: Self.hm(d.asleepMinutes),
                      trailing: d.score.map { "\($0)" } ?? "—", accent: true)
            metricRow(icon: "waveform.path", label: "SOLIDITY",
                      sub: "CONTINUITY \(Self.solidityWord(d.continuityClass))",
                      trailing: d.continuity.map { String(format: "%.1f", $0) } ?? "—", accent: false)
            metricRow(icon: "moon.stars", label: "REGENERATION",
                      sub: "REM · DEEP",
                      trailing: "\(Self.regenPct(d.stages))%", accent: false)
        }
    }

    private func metricRow(icon: String, label: String, sub: String,
                           trailing: String, accent: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(accent ? Theme.accent : Theme.muted)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(Theme.mono(8.5, .semibold)).tracking(1.5)
                    .foregroundStyle(Theme.text.opacity(0.38))
                Text(sub).font(Theme.mono(11, .medium)).foregroundStyle(Theme.text.opacity(0.5))
            }
            Spacer()
            Text(trailing).font(Theme.mono(22, .heavy)).tracking(-1)
                .foregroundStyle(accent ? Theme.accent : Theme.text).monospacedDigit()
        }
        .padding(.vertical, 14).padding(.horizontal, 18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Week view

    @ViewBuilder
    private func weekView(_ week: SleepWeekDetail?) -> some View {
        if let week, !week.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                SleepMatrixChart(week: week)
                SleepTrendChart(week: week)
                consolidation(week)
            }
        } else {
            emptyState
        }
    }

    private func consolidation(_ week: SleepWeekDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEEKLY CONSOLIDATION")
                .font(Theme.mono(10, .semibold)).tracking(2)
                .foregroundStyle(Theme.text.opacity(0.45))
            HStack(spacing: 18) {
                ConsolidationWheel(stages: week.avgStages)
                    .frame(width: 118, height: 118)
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(week.avgStages) { bar in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.zoneRamp[bar.level]).frame(width: 8, height: 8)
                            Text(bar.name).font(Theme.mono(9, .semibold)).tracking(1)
                                .foregroundStyle(Theme.text.opacity(0.5))
                            Spacer()
                            Text(Self.hm(bar.minutes)).font(Theme.mono(10, .bold))
                                .foregroundStyle(Theme.text)
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                summaryCell("AVG SLEEP", week.avgScore.map { "\($0)" } ?? "—", "")
                summaryCell("CONTINUITY", week.avgContinuity.map { String(format: "%.1f", $0) } ?? "—", "/5")
                summaryCell("INTERRUPT", "\(week.avgInterruptMinutes)", "MIN")
            }
        }
    }

    private func summaryCell(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(Theme.mono(8, .semibold)).tracking(1.5)
                .foregroundStyle(Theme.text.opacity(0.4))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(Theme.mono(20, .heavy)).tracking(-1)
                    .foregroundStyle(Theme.text).monospacedDigit()
                if !unit.isEmpty {
                    Text(unit).font(Theme.mono(9, .semibold)).foregroundStyle(Theme.muted)
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Empty state (NO RECORD / NO TELEMETRY)

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("—").font(Theme.mono(34, .heavy)).foregroundStyle(Theme.faint)
            Text("NO RECORD · NO TELEMETRY")
                .font(Theme.mono(10, .semibold)).tracking(2)
                .foregroundStyle(Theme.muted)
            Text("Band wasn't worn. Wear it to sleep to record your hypnogram and sleep score.")
                .font(Theme.mono(10, .medium)).foregroundStyle(Theme.text.opacity(0.4))
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Text("PULL TO SYNC ON DASHBOARD")
                .font(Theme.mono(9, .bold)).tracking(2)
                .foregroundStyle(Theme.accent).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    // MARK: - Formatting

    /// Fractional hour (may exceed 24) → `"3:23 AM"`.
    static func clock(_ hour: Double) -> String {
        let h24 = Int(hour.truncatingRemainder(dividingBy: 24))
        let minutes = Int((hour - Double(Int(hour))) * 60 + 0.5) % 60
        let suffix = h24 < 12 ? "AM" : "PM"
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return String(format: "%d:%02d %@", h12, minutes, suffix)
    }

    static func hm(_ minutes: Int) -> String {
        "\(minutes / 60)H\(String(format: "%02d", minutes % 60))M"
    }

    static func solidityWord(_ continuityClass: Int?) -> String {
        switch continuityClass {
        case .some(let c) where c >= 3: "GOOD"
        case .some(let c) where c == 2: "FAIR"
        case .some: "POOR"
        default: "—"
        }
    }

    static func regenWord(_ stages: [SleepStageBar]) -> String {
        regenPct(stages) >= 35 ? "GOOD" : "LOW"
    }

    /// REM + DEEP share of total asleep minutes, as a percentage.
    static func regenPct(_ stages: [SleepStageBar]) -> Int {
        let asleep = stages.filter { $0.stage != .wake }.reduce(0) { $0 + $1.minutes }
        guard asleep > 0 else { return 0 }
        let regen = stages.filter { $0.stage == .rem || $0.stage == .deep }.reduce(0) { $0 + $1.minutes }
        return Int((Double(regen) / Double(asleep) * 100).rounded())
    }
}

// MARK: - Hypnogram + HR chart

/// The signature day viz: a stepped hypnogram band (WAKE→DEEP lanes) under a
/// continuous-HR line, both anchored on the night window. Degrades to the band
/// alone when HR is absent (mirrors `ActivityHRChart`). `p` drives the draw-in.
private struct SleepHypnogramChart: View {
    let detail: SleepDetail
    @State private var p: Double = 0

    private let hrTop: CGFloat = 14
    private let hrBase: CGFloat = 92
    private let hypTop: CGFloat = 108
    private let hypBot: CGFloat = 200

    private var span: Double { max(detail.window.upperBound - detail.window.lowerBound, 0.1) }
    private var dMin: Double { Double(detail.hr.map(\.bpm).min() ?? 45) - 4 }
    private var dMax: Double { Double(detail.hr.map(\.bpm).max() ?? 70) + 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HYPNOGRAM · \(detail.cycles) CYCLES")
                    .font(Theme.mono(10, .semibold)).tracking(2)
                    .foregroundStyle(Theme.text.opacity(0.45))
                Spacer()
            }
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, _ in draw(&ctx, width: w) }
                    if !detail.hr.isEmpty {
                        HRShape(samples: detail.hr, window: detail.window, dMin: dMin, dMax: dMax,
                                hrTop: hrTop, hrBase: hrBase)
                            .trim(from: 0, to: p)
                            .stroke(Theme.accent,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    } else {
                        Text("NO HR DATA")
                            .font(Theme.mono(9, .semibold)).tracking(1.5)
                            .foregroundStyle(Theme.faint)
                            .position(x: w / 2, y: (hrTop + hrBase) / 2).opacity(p)
                    }
                }
            }
            .frame(height: 208)
            axis
        }
        .onAppear { withAnimation(.easeOut(duration: 1.15)) { p = 1 } }
    }

    private func draw(_ ctx: inout GraphicsContext, width w: CGFloat) {
        func x(_ hour: Double) -> CGFloat { CGFloat((hour - detail.window.lowerBound) / span) * w }

        // Lane guides for the four stages.
        for depth in 0...3 {
            let y = hypTop + CGFloat(depth) / 3 * (hypBot - hypTop)
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: w, y: y))
            ctx.stroke(line, with: .color(Theme.grid), lineWidth: 1)
        }

        // Stepped hypnogram segments (grow in with `p`).
        func laneY(_ stage: SleepStage) -> CGFloat {
            hypTop + CGFloat(stage.depth) / 3 * (hypBot - hypTop)
        }
        var previousY: CGFloat?
        for seg in detail.hypnogram {
            let y = laneY(seg.stage)
            let x0 = x(seg.startHour), x1 = x(min(seg.endHour, detail.window.upperBound))
            let visible = x0 + (x1 - x0) * CGFloat(p)
            var bar = Path()
            bar.move(to: CGPoint(x: x0, y: y))
            bar.addLine(to: CGPoint(x: visible, y: y))
            ctx.stroke(bar, with: .color(Theme.zoneRamp[seg.stage.rampLevel]),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round))
            if let py = previousY {
                var connector = Path()
                connector.move(to: CGPoint(x: x0, y: py))
                connector.addLine(to: CGPoint(x: x0, y: y))
                ctx.stroke(connector, with: .color(Theme.faint.opacity(0.5 * p)), lineWidth: 1)
            }
            previousY = y
        }
    }

    private var axis: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let ticks = (0...4).map { detail.window.lowerBound + Double($0) * span / 4 }
            ForEach(Array(ticks.enumerated()), id: \.offset) { i, hour in
                Text(SleepDetailView.clock(hour).replacingOccurrences(of: " AM", with: "")
                    .replacingOccurrences(of: " PM", with: ""))
                    .font(Theme.mono(8, .semibold))
                    .foregroundStyle(Theme.text.opacity(0.35))
                    .fixedSize()
                    .position(x: anchorX(i, count: ticks.count, width: w), y: 7)
            }
        }
        .frame(height: 14)
    }

    private func anchorX(_ i: Int, count: Int, width w: CGFloat) -> CGFloat {
        let x = CGFloat(i) / CGFloat(count - 1) * w
        if i == 0 { return x + 12 }
        if i == count - 1 { return x - 12 }
        return x
    }
}

/// The HR polyline as a `Shape`, so it can `.trim` for the draw-in. Anchored on
/// the night window (unlike `ActivityHRChart`'s fixed 24h origin).
private struct HRShape: Shape {
    let samples: [SleepHRSample]
    let window: ClosedRange<Double>
    let dMin: Double
    let dMax: Double
    let hrTop: CGFloat
    let hrBase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else { return path }
        let span = max(window.upperBound - window.lowerBound, 0.1)
        func x(_ hour: Double) -> CGFloat { CGFloat((hour - window.lowerBound) / span) * rect.width }
        func y(_ bpm: Int) -> CGFloat {
            let v = min(max(Double(bpm), dMin), dMax)
            return hrTop + CGFloat(1 - (v - dMin) / max(dMax - dMin, 1)) * (hrBase - hrTop)
        }
        path.move(to: CGPoint(x: x(samples[0].hour), y: y(samples[0].bpm)))
        for s in samples.dropFirst() { path.addLine(to: CGPoint(x: x(s.hour), y: y(s.bpm))) }
        return path
    }
}

// MARK: - Week: sleep matrix

/// Per-night stacked stage bars (SLEEP MATRIX). Bar height ∝ asleep minutes;
/// segments coloured by stage. `GeometryReader` layout, hand-rolled like the
/// activity charts.
private struct SleepMatrixChart: View {
    let week: SleepWeekDetail
    @State private var p: Double = 0

    private var maxMinutes: Int { max(week.matrix.map(\.asleepMinutes).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SLEEP MATRIX")
                .font(Theme.mono(10, .semibold)).tracking(2)
                .foregroundStyle(Theme.text.opacity(0.45))
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(week.matrix) { night in
                    VStack(spacing: 6) {
                        column(night)
                        Text(night.dayLabel)
                            .font(Theme.mono(8, .semibold))
                            .foregroundStyle(Theme.text.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 168)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { p = 1 } }
    }

    private func column(_ night: SleepMatrixNight) -> some View {
        let asleep = night.stages.filter { $0.stage != .wake }
        let height = 150 * CGFloat(night.asleepMinutes) / CGFloat(maxMinutes)
        return VStack(spacing: 1) {
            ForEach(asleep.sorted { $0.stage.depth < $1.stage.depth }) { bar in
                Theme.zoneRamp[bar.level]
                    .frame(height: height * CGFloat(bar.minutes)
                           / CGFloat(max(night.asleepMinutes, 1)) * CGFloat(p))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150, alignment: .bottom)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Week: trend line

/// Weekly SLEEP-score trend polyline over the 7 nights.
private struct SleepTrendChart: View {
    let week: SleepWeekDetail
    @State private var p: Double = 0

    private var points: [(Double, Int)] {
        week.trend.enumerated().compactMap { i, t in t.score.map { (Double(i), $0) } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TREND · SLEEP")
                .font(Theme.mono(10, .semibold)).tracking(2)
                .foregroundStyle(Theme.text.opacity(0.45))
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let count = max(week.trend.count - 1, 1)
                TrendShape(points: points, count: count)
                    .trim(from: 0, to: p)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: w, height: h)
            }
            .frame(height: 90)
            HStack {
                ForEach(week.trend) { t in
                    Text(t.dayLabel).font(Theme.mono(8, .semibold))
                        .foregroundStyle(Theme.text.opacity(0.4)).frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.cardBorder, lineWidth: 1))
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { p = 1 } }
    }
}

private struct TrendShape: Shape {
    let points: [(Double, Int)]
    let count: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }
        func x(_ i: Double) -> CGFloat { CGFloat(i / Double(count)) * rect.width }
        func y(_ score: Int) -> CGFloat {
            CGFloat(1 - Double(min(max(score, 0), 100)) / 100) * rect.height
        }
        path.move(to: CGPoint(x: x(points[0].0), y: y(points[0].1)))
        for pt in points.dropFirst() { path.addLine(to: CGPoint(x: x(pt.0), y: y(pt.1))) }
        return path
    }
}

// MARK: - Weekly consolidation wheel

/// A donut split by the averaged stage proportions — the custom consolidation
/// viz (`GeometryReader`/`Path`, like `ActivityClockChart`).
private struct ConsolidationWheel: View {
    let stages: [SleepStageBar]
    @State private var p: Double = 0

    var body: some View {
        Canvas { ctx, size in draw(&ctx, size: size) }
            .onAppear { withAnimation(.easeOut(duration: 1.0)) { p = 1 } }
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = min(size.width, size.height)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = s * 0.42
        let total = max(stages.reduce(0) { $0 + $1.minutes }, 1)
        var startAngle = -90.0
        for bar in stages where bar.minutes > 0 {
            let sweep = 360.0 * Double(bar.minutes) / Double(total) * p
            var arc = Path()
            arc.addArc(center: c, radius: r,
                       startAngle: .degrees(startAngle), endAngle: .degrees(startAngle + sweep),
                       clockwise: false)
            ctx.stroke(arc, with: .color(Theme.zoneRamp[bar.level]),
                       style: StrokeStyle(lineWidth: s * 0.16, lineCap: .butt))
            startAngle += 360.0 * Double(bar.minutes) / Double(total)
        }
        ctx.draw(Text("CYCLES").font(Theme.mono(8, .bold))
            .foregroundColor(Theme.text.opacity(0.5)), at: c)
    }
}

#Preview {
    NavigationStack {
        SleepDetailView(model: SleepDetailModel())
    }
}
