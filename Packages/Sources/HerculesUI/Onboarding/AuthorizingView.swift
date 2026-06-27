import SwiftUI

/// 02c · AUTHORIZING — shown while tokens are exchanged and the user registered,
/// between the secure hand-off and the initial sync.
struct AuthorizingView: View {
    @State private var spin = false

    private let handshake: [(name: String, stat: String)] = [
        ("v3 ACCESSLINK", "BEARER"),
        ("v4 REALM", "ACCESS + REFRESH"),
        ("USER REGISTRATION", "POST /v3/users"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("SYSTEM AUTHENTICATION")
                .font(Theme.mono(9, .semibold))
                .tracking(2)
                .foregroundStyle(Theme.muted)

            Spacer()

            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)

            Text("AUTHORIZING…")
                .font(Theme.mono(16, .bold))
                .tracking(2)
                .padding(.top, 22)

            Text("Exchanging your authorization code for a secure token and registering your device.")
                .font(Theme.mono(12, .medium))
                .foregroundStyle(Theme.text.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
                .padding(.top, 10)

            VStack(spacing: 8) {
                ForEach(handshake, id: \.name) { row in
                    HStack {
                        Text(row.name)
                            .font(Theme.mono(10.5, .semibold))
                            .tracking(1)
                        Spacer()
                        Text(row.stat)
                            .font(Theme.mono(10.5, .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Spacer()
        }
        .padding(.vertical, 28)
        .onAppear { spin = true }
    }
}
