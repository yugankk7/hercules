import SwiftUI
import HerculesUI
import PolarProtocol
import PolarStore

@main
struct HerculesApp: App {

    /// The app-wide auth/connection state. Routes onboarding vs. dashboard.
    @State private var auth = AuthManager.live()

    /// The connected-state dashboard view-model (stub-backed this slice — a
    /// `PolarStore`-backed provider and the real sync engine drop in later).
    @State private var dashboard = DashboardModel()

    init() {
        // HERC-002 sanity check: confirm the GRDB store wires up at launch.
        #if DEBUG
        let ok = PolarDatabase.selfTest()
        print("[Hercules] PolarStore self-test: \(ok ? "ok" : "FAILED")")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.state {
                case .connected:
                    // HERC-065: the navigable dashboard shell + bottom-tab nav.
                    RootTabView(auth: auth, dashboard: dashboard)
                default:
                    OnboardingFlowView(manager: auth)
                }
            }
            .task { auth.bootstrap() }
            // HERC-001 fallback: ASWebAuthenticationSession captures the callback
            // directly; this remains as a safety net if that path is ever bypassed.
            .onOpenURL { url in
                print("[Hercules] opened via URL: \(url.absoluteString)")
            }
        }
    }
}
