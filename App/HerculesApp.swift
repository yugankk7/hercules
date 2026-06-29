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

    /// The **one** persistent store, opened at the composition root and shared by
    /// reference (A1/A2 of `PRE-EPIC-5-store-readiness.md`). One on-disk file, one
    /// `DatabasePool` — never opened twice on the same path. The Epic 5 sync engine
    /// (writes via `StoreWriting`) and the Epic 6 store-backed dashboard provider
    /// (reads via `StoreReading`) both receive *this* instance; until then it is
    /// provisioned and held here so that wiring is a one-line injection.
    private let store: PolarDatabase?

    init() {
        do {
            let store = try PolarDatabase.onDisk()
            self.store = store
            #if DEBUG
            print("[Hercules] PolarStore opened at Application Support/\(PolarDatabase.defaultFilename)")
            #endif
        } catch {
            // A failed open leaves the app in its pre-sync (stub/empty) state rather
            // than crashing; the real coordinator will surface this once it exists.
            self.store = nil
            print("[Hercules] PolarStore failed to open: \(error)")
        }
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
