import SwiftUI

/// 03 · INITIAL SYNC — the terminal progress readout (the ONLY loading pattern):
/// giant count-up %, a linear master bar, and per-domain `[||||    ]` rows, all
/// bound to `AuthManager.syncProgress`. Never a circular spinner.
struct InitialSyncView: View {
    let progress: Double

    private struct Row {
        let name: String
        let total: Int
        let unit: String
    }

    private let rows: [Row] = [
        .init(name: "SLEEP", total: 28, unit: "nights"),
        .init(name: "RECHARGE", total: 28, unit: "nights"),
        .init(name: "ACTIVITY", total: 28, unit: "days"),
        .init(name: "HEART RATE", total: 40320, unit: "samples"),
        .init(name: "WORKOUTS", total: 46, unit: "sessions"),
        .init(name: "SLEEPWISE", total: 1, unit: "model"),
    ]

    private var pct: Int { Int((progress * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INITIALIZING DASHBOARD")
                .font(Theme.mono(9, .semibold))
                .tracking(2)
                .foregroundStyle(Theme.muted)

            Text("Pulling 28 days of telemetry · 1.4M data points")
                .font(Theme.mono(11, .medium))
                .foregroundStyle(Theme.text.opacity(0.5))
                .padding(.top, 8)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(pct)")
                    .font(Theme.mono(72, .heavy))
                    .tracking(-4)
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
                Text("%")
                    .font(Theme.mono(24, .bold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 16)

            // Master bar.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.slate.opacity(0.4))
                    Capsule().fill(Theme.accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
            .padding(.top, 8)

            VStack(spacing: 12) {
                ForEach(rows, id: \.name) { row in
                    DomainRow(row: row, progress: progress)
                }
            }
            .padding(.top, 28)

            Spacer()

            Text(pct >= 100 ? "SYNC COMPLETE" : "SYNCING…")
                .font(Theme.mono(10, .semibold))
                .tracking(2)
                .foregroundStyle(pct >= 100 ? Theme.accent : Theme.muted)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
    }

    private struct DomainRow: View {
        let row: Row
        let progress: Double

        /// Each domain fills on a staggered slice of the overall progress.
        private var local: Double {
            let start = 0.05
            let span = 0.8
            return min(1, max(0, (progress - start) / span))
        }
        private var filled: Int { Int((local * 10).rounded()) }
        private var done: Bool { local >= 1 }
        private var ticks: String {
            "[" + String(repeating: "|", count: filled) + String(repeating: " ", count: 10 - filled) + "]"
        }
        private var stat: String {
            guard local > 0 else { return "—" }
            if row.name == "SLEEPWISE" { return done ? "OK" : "CALC" }
            let value = Int((local * Double(row.total)).rounded())
            return value.formatted()
        }

        var body: some View {
            HStack {
                Circle()
                    .fill(local > 0 ? Theme.accent : Theme.slate)
                    .frame(width: 6, height: 6)
                Text(row.name)
                    .font(Theme.mono(11, .semibold))
                    .tracking(1)
                    .foregroundStyle(local > 0 ? Theme.text : Theme.faint)
                Spacer()
                Text(ticks)
                    .font(Theme.mono(11, .medium))
                    .foregroundStyle(local > 0 ? Theme.accent : Theme.faint)
                Text(stat)
                    .font(Theme.mono(11, .semibold))
                    .foregroundStyle(done ? Theme.text : (local > 0 ? Theme.accent : Theme.faint))
                    .monospacedDigit()
                    .frame(width: 64, alignment: .trailing)
            }
        }
    }
}
