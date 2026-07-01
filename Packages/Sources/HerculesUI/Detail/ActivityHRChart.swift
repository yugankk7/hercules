import SwiftUI
import PolarProtocol

/// The linear signature viz: a 24h continuous-HR curve over an intensity density
/// band, with a night-sleep marker and 6-hour gridlines — the hero of the Daily
/// Activity detail. Draws from real `hr_minute` + `activity_zones`; with no HR synced
/// it degrades to the band alone. `p` (0→1) drives the synchronized draw-in.
struct ActivityHRChart: View {
    let detail: ActivityDetail
    @State private var p: Double = 0

    // Plot geometry (points, in a fixed 200-tall space — see `frame(height:)`).
    private let hrTop: CGFloat = 16
    private let hrBase: CGFloat = 150
    private let bandTop: CGFloat = 158
    private let bandBot: CGFloat = 192

    private var dMin: Double { min(40, Double(detail.hr.map(\.bpm).min() ?? 40) - 5) }
    private var dMax: Double { max(168, Double(detail.hr.map(\.bpm).max() ?? 168) + 6) }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, _ in draw(&ctx, width: w) }
                    if !detail.hr.isEmpty {
                        HRLineShape(samples: detail.hr, dMin: dMin, dMax: dMax,
                                    hrTop: hrTop, hrBase: hrBase)
                            .trim(from: 0, to: p)
                            .stroke(Theme.accent,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        bubbles(width: w)
                    } else {
                        Text("NO HR DATA")
                            .font(Theme.mono(9, .semibold)).tracking(1.5)
                            .foregroundStyle(Theme.faint)
                            .position(x: w / 2, y: (hrTop + hrBase) / 2)
                            .opacity(p)
                    }
                }
            }
            .frame(height: 200)
            axis
        }
        .onAppear { withAnimation(.easeOut(duration: 1.15)) { p = 1 } }
    }

    // MARK: - Canvas layers

    private func draw(_ ctx: inout GraphicsContext, width w: CGFloat) {
        func x(_ hour: Double) -> CGFloat { CGFloat(hour / 24) * w }

        // 6-hour gridlines
        for hour in stride(from: 0.0, through: 24, by: 6) {
            var line = Path()
            line.move(to: CGPoint(x: x(hour), y: hrTop - 4))
            line.addLine(to: CGPoint(x: x(hour), y: bandBot))
            ctx.stroke(line, with: .color(Theme.grid), lineWidth: 1)
        }

        // Night-sleep marker on the band
        if let sleep = detail.sleepBlock {
            let rect = CGRect(x: x(sleep.lowerBound), y: bandTop - 1,
                              width: x(sleep.upperBound) - x(sleep.lowerBound),
                              height: bandBot - bandTop + 2)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Theme.slate.opacity(0.5)))
        }

        // Intensity density band (grows up from the baseline with `p`)
        let n = detail.intensity.count
        if n > 0 {
            for (i, level) in detail.intensity.enumerated() where level > 0 {
                let cx = (CGFloat(i) + 0.5) / CGFloat(n) * w
                let full = CGFloat(level) / 4 * (bandBot - bandTop)
                var bar = Path()
                bar.move(to: CGPoint(x: cx, y: bandBot))
                bar.addLine(to: CGPoint(x: cx, y: bandBot - full * CGFloat(p)))
                ctx.stroke(bar, with: .color(Theme.zoneRamp[level].opacity(0.9)), lineWidth: 1.4)
            }
        }

        // HR area fill (fades in under the line)
        guard !detail.hr.isEmpty else { return }
        func y(_ bpm: Int) -> CGFloat {
            let v = min(max(Double(bpm), dMin), dMax)
            return hrTop + CGFloat(1 - (v - dMin) / (dMax - dMin)) * (hrBase - hrTop)
        }
        var fill = Path()
        fill.move(to: CGPoint(x: x(detail.hr[0].hour), y: hrBase))
        for s in detail.hr { fill.addLine(to: CGPoint(x: x(s.hour), y: y(s.bpm))) }
        fill.addLine(to: CGPoint(x: x(detail.hr.last!.hour), y: hrBase))
        fill.closeSubpath()
        ctx.fill(fill, with: .linearGradient(
            Gradient(colors: [Theme.accent.opacity(0.18 * p), Theme.accent.opacity(0)]),
            startPoint: CGPoint(x: 0, y: hrTop), endPoint: CGPoint(x: 0, y: hrBase)))
    }

    // MARK: - HR min/max callouts

    @ViewBuilder
    private func bubbles(width w: CGFloat) -> some View {
        if let lo = detail.hr.min(by: { $0.bpm < $1.bpm }),
           let hi = detail.hr.max(by: { $0.bpm < $1.bpm }) {
            bubble(lo, width: w, hot: false)
            bubble(hi, width: w, hot: true)
        }
    }

    private func bubble(_ s: ActivityHRSample, width w: CGFloat, hot: Bool) -> some View {
        let v = min(max(Double(s.bpm), dMin), dMax)
        let y = hrTop + CGFloat(1 - (v - dMin) / (dMax - dMin)) * (hrBase - hrTop)
        return Text("\(s.bpm)")
            .font(Theme.mono(11, .heavy))
            .foregroundStyle(hot ? Color.black : Theme.text)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(hot ? Theme.accent : Theme.cardBorder, in: Capsule())
            .position(x: CGFloat(s.hour / 24) * w, y: max(y - 16, 8))
            .opacity(p)
    }

    private var axis: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let labels = ["12 AM", "6 AM", "12 PM", "6 PM", "12 AM"]
            ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                Text(label)
                    .font(Theme.mono(8, .semibold))
                    .foregroundStyle(Theme.text.opacity(0.35))
                    .fixedSize()
                    .position(x: anchorX(i, count: labels.count, width: w), y: 7)
            }
        }
        .frame(height: 14)
    }

    /// First/last labels hug the edges; the rest centre on their gridline.
    private func anchorX(_ i: Int, count: Int, width w: CGFloat) -> CGFloat {
        let x = CGFloat(i) / CGFloat(count - 1) * w
        if i == 0 { return x + 14 }
        if i == count - 1 { return x - 14 }
        return x
    }
}

/// The HR polyline as a `Shape`, so it can `.trim` for the draw-in animation.
private struct HRLineShape: Shape {
    let samples: [ActivityHRSample]
    let dMin: Double
    let dMax: Double
    let hrTop: CGFloat
    let hrBase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else { return path }
        func x(_ hour: Double) -> CGFloat { CGFloat(hour / 24) * rect.width }
        func y(_ bpm: Int) -> CGFloat {
            let v = min(max(Double(bpm), dMin), dMax)
            return hrTop + CGFloat(1 - (v - dMin) / (dMax - dMin)) * (hrBase - hrTop)
        }
        path.move(to: CGPoint(x: x(samples[0].hour), y: y(samples[0].bpm)))
        for s in samples.dropFirst() { path.addLine(to: CGPoint(x: x(s.hour), y: y(s.bpm))) }
        return path
    }
}
