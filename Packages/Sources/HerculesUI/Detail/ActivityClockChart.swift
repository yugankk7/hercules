import SwiftUI
import PolarProtocol

/// The radial signature viz: a 24-hour dial with intensity spikes around the rim, a
/// sleep-window ring, and a "now" needle — the toggle alternate to `ActivityHRChart`.
/// Reads the same `ActivityDetail`. `p` (0→1) grows the spikes in.
struct ActivityClockChart: View {
    let detail: ActivityDetail
    /// Current time as a fractional hour (0…24) for the needle.
    let nowHour: Double
    @State private var p: Double = 0

    var body: some View {
        Canvas { ctx, size in draw(&ctx, size: size) }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
            .onAppear { withAnimation(.easeOut(duration: 1.0)) { p = 1 } }
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = min(size.width, size.height)
        let c = CGPoint(x: size.width / 2, y: s / 2)
        let rDial = s * 0.27, rSpikeIn = s * 0.37, rSpikeMax = s * 0.094
        let rEdge = s * 0.47, rSleep = s * 0.325

        func polar(_ t: Double, _ r: CGFloat) -> CGPoint {
            let a = (-90 - (t / 24) * 360) * .pi / 180
            return CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
        }

        // Outer faint rings
        for r in [rEdge, rSpikeIn - 3] {
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                       with: .color(Theme.grid), lineWidth: 1)
        }

        // Hour ticks
        for t in 0..<24 {
            let major = t % 6 == 0
            var tick = Path()
            tick.move(to: polar(Double(t), rSpikeIn - 3))
            tick.addLine(to: polar(Double(t), rSpikeIn - 3 - (major ? 8 : 4)))
            ctx.stroke(tick, with: .color(major ? Theme.faint : Theme.cardBorder),
                       lineWidth: major ? 1.4 : 1)
        }

        // Dial face + hour numbers
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - rDial, y: c.y - rDial, width: rDial * 2, height: rDial * 2)),
                 with: .color(Theme.slate.opacity(0.16)))
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rDial, y: c.y - rDial, width: rDial * 2, height: rDial * 2)),
                   with: .color(Theme.cardBorder), lineWidth: 1)
        for (label, t) in [("00", 0.0), ("06", 6.0), ("12", 12.0), ("18", 18.0)] {
            let pt = polar(t, rDial - 15)
            ctx.draw(Text(label).font(Theme.mono(13, .heavy)).foregroundColor(Theme.text), at: pt)
        }

        // Sleep-window ring
        if let sleep = detail.sleepBlock {
            var band = Path()
            band.move(to: polar(sleep.lowerBound, rSleep))
            var t = sleep.lowerBound
            while t <= sleep.upperBound { band.addLine(to: polar(t, rSleep)); t += 0.08 }
            ctx.stroke(band, with: .color(Theme.slate.opacity(0.9 * p)),
                       style: StrokeStyle(lineWidth: s * 0.04, lineCap: .round))
        }

        // Intensity spikes (grow outward with `p`)
        let n = detail.intensity.count
        for (i, level) in detail.intensity.enumerated() where level > 0 {
            let t = Double(i) / Double(n) * 24
            let len = rSpikeIn + CGFloat(level) / 4 * rSpikeMax * CGFloat(p)
            var spike = Path()
            spike.move(to: polar(t, rSpikeIn))
            spike.addLine(to: polar(t, len))
            ctx.stroke(spike, with: .color(Theme.zoneRamp[level]),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }

        // Now needle + hub
        var needle = Path()
        needle.move(to: c)
        needle.addLine(to: polar(nowHour, rEdge + 2))
        ctx.stroke(needle, with: .color(Theme.text.opacity(0.85)),
                   style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)),
                 with: .color(Theme.text))
    }
}
