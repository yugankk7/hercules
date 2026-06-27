import SwiftUI
import PolarProtocol

/// Routes the onboarding experience by observing `AuthManager.step`. The
/// `handoff` step coincides with the system `ASWebAuthenticationSession` sheet
/// presented from `OAuthClient`. Presentation only — all logic lives in
/// `AuthManager` (Safeguard / Norm: views never touch network or Keychain).
public struct OnboardingFlowView: View {
    @Bindable private var manager: AuthManager

    public init(manager: AuthManager) {
        self.manager = manager
    }

    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch manager.step {
            case .welcome:
                WelcomeView(manager: manager)
            case .consent, .handoff:
                ConsentView(manager: manager)
            case .authorizing:
                AuthorizingView()
            case .syncing, .done:
                InitialSyncView(progress: manager.syncProgress)
            }
        }
        .foregroundStyle(Theme.text)
        .animation(.easeOut(duration: 0.35), value: manager.step)
    }
}
