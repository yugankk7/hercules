import SwiftUI
import PolarProtocol

/// 07 · PROFILE — connection status + the app's single sign-out control.
/// DISCONNECT delegates entirely to `AuthManager.signOut()` (which clears the
/// Keychain), routing back to onboarding (`connected → disconnected`). This is
/// the only place sign-out lives.
struct ProfileView: View {
    let auth: AuthManager

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("PROFILE")
                    .font(Theme.mono(9, .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.muted)

                Text("ACCOUNT")
                    .font(Theme.mono(22, .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.text)
                    .padding(.top, 18)

                statusRow
                    .padding(.top, 20)

                Spacer()

                Button {
                    auth.signOut()
                } label: {
                    Text("DISCONNECT")
                        .font(Theme.mono(14, .heavy))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .overlay(Capsule().strokeBorder(Theme.accent, lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                Text("CLEARS CREDENTIALS · RETURNS TO WELCOME")
                    .font(Theme.mono(9, .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 8, height: 8)
            Text("CONNECTED")
                .font(Theme.mono(12, .bold))
                .tracking(1)
                .foregroundStyle(Theme.text)
            Spacer()
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
    }
}
