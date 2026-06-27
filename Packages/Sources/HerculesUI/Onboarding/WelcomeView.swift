import SwiftUI
import PolarProtocol

/// 01 · WELCOME — logo, value prop, CONNECT POLAR CTA → `connect()`.
struct WelcomeView: View {
    let manager: AuthManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("01 · WELCOME")
                Spacer()
                Text("READY")
                    .foregroundStyle(Theme.accent)
            }
            .font(Theme.mono(9, .semibold))
            .tracking(2)
            .foregroundStyle(Theme.muted)

            Spacer()

            VStack(spacing: 12) {
                Text("HERCULES")
                    .font(Theme.mono(34, .heavy))
                    .tracking(4)
                    .foregroundStyle(Theme.accent)
                Text("TELEMETRY")
                    .font(Theme.mono(11, .semibold))
                    .tracking(4)
                    .foregroundStyle(Theme.muted)
            }

            Spacer().frame(height: 40)

            VStack(spacing: 16) {
                Text("YOUR BODY, AS AN INSTRUMENT.")
                    .font(Theme.mono(15, .bold))
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                Text("Every metric your Polar already tracks — sleep, recharge, activity — rebuilt as a precision dashboard. No fluff. No spinners.")
                    .font(Theme.mono(12.5, .medium))
                    .foregroundStyle(Theme.text.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 24)

            Spacer()

            PrimaryCTA(title: "CONNECT POLAR") {
                Task { await manager.connect() }
            }
            .disabled(manager.state == .connecting)

            Text("SECURE OAUTH · TAKES ~30 SECONDS")
                .font(Theme.mono(9, .semibold))
                .tracking(2)
                .foregroundStyle(Theme.muted)
                .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
    }
}
