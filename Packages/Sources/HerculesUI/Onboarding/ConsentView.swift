import SwiftUI
import PolarProtocol

/// 02 · AUTHENTICATION — read-only scope list + AUTHORIZE CTA → `connect()`.
/// Also the recovery screen after a cancel or recoverable error (`lastError`).
struct ConsentView: View {
    let manager: AuthManager

    private struct Domain: Identifiable {
        let id = UUID()
        let glyph: String
        let name: String
        let desc: String
    }

    private let domains: [Domain] = [
        .init(glyph: "Z", name: "SLEEP", desc: "Stages, duration, SleepWise"),
        .init(glyph: "R", name: "RECHARGE", desc: "Nightly recovery + ANS"),
        .init(glyph: "A", name: "ACTIVITY", desc: "Steps, calories, load"),
        .init(glyph: "H", name: "HEART RATE", desc: "Continuous + resting HR"),
        .init(glyph: "W", name: "WORKOUTS", desc: "Sessions, routes, zones"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SYSTEM AUTHENTICATION")
                Spacer()
                Text("STEP 02 / 03")
            }
            .font(Theme.mono(9, .semibold))
            .tracking(2)
            .foregroundStyle(Theme.muted)

            Text("GRANT DATA ACCESS")
                .font(Theme.mono(22, .heavy))
                .tracking(-0.5)
                .padding(.top, 18)

            Text("Hercules reads from your Polar v3 + v4 realms. Nothing is written back. Revoke anytime.")
                .font(Theme.mono(12.5, .medium))
                .foregroundStyle(Theme.text.opacity(0.55))
                .lineSpacing(3)
                .padding(.top, 8)

            HStack(spacing: 8) {
                Pill(text: "READ-ONLY")
                Pill(text: "GRANTED IN ONE CONSENT")
            }
            .padding(.top, 14)

            VStack(spacing: 10) {
                ForEach(domains) { domain in
                    ScopeRow(domain: domain)
                }
            }
            .padding(.top, 20)

            if let error = manager.lastError {
                ErrorBanner(error: error)
                    .padding(.top, 16)
            }

            Spacer()

            PrimaryCTA(title: "AUTHORIZE") {
                Task { await manager.connect() }
            }
            .disabled(manager.state == .connecting)

            Text("OPENS POLAR.COM · ENCRYPTED")
                .font(Theme.mono(9, .semibold))
                .tracking(2)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
    }

    // MARK: - Subcomponents

    private struct ScopeRow: View {
        let domain: Domain
        var body: some View {
            HStack(spacing: 14) {
                Text(domain.glyph)
                    .font(Theme.mono(15, .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.slate, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(domain.name)
                        .font(Theme.mono(12, .bold))
                        .tracking(1)
                    Text(domain.desc)
                        .font(Theme.mono(10.5, .medium))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
        }
    }

    private struct Pill: View {
        let text: String
        var body: some View {
            Text(text)
                .font(Theme.mono(9, .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(Theme.slate, lineWidth: 1))
        }
    }

    private struct ErrorBanner: View {
        let error: AuthError
        var body: some View {
            Text(message)
                .font(Theme.mono(11, .semibold))
                .foregroundStyle(Theme.accent)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }

        private var message: String {
            switch error {
            case .missingSecrets:
                return "Add your Polar client secret to Secrets.plist, then relaunch."
            case .cancelled:
                return "Connection cancelled. Tap Authorize to try again."
            case .scopeDenied:
                return "Some data access was declined. Authorize again to grant full access."
            default:
                return "Couldn't connect. Check your connection and try again."
            }
        }
    }
}
