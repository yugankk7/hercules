import SwiftUI
import HerculesUI
import PolarProtocol
import PolarStore

@main
struct HerculesApp: App {

    /// The app-wide auth/connection state. Routes onboarding vs. dashboard.
    @State private var auth: AuthManager

    /// The connected-state dashboard view-model. Its refresh coordinator is the
    /// real `SyncEngine` when the store opened, else the no-network stub.
    @State private var dashboard: DashboardModel

    /// The **one** persistent store, opened at the composition root and shared by
    /// reference (A1/A2 of `PRE-EPIC-5-store-readiness.md`). One on-disk file, one
    /// `DatabasePool` — never opened twice on the same path. The Epic 5 sync engine
    /// (writes via `StoreWriting`, reads `lastSync` via `SyncStore`) receives *this*
    /// instance; the Epic 6 store-backed provider (reads via `StoreReading`) will too.
    private let store: PolarDatabase?

    init() {
        let auth = AuthManager.live()
        let openedStore: PolarDatabase?
        let model: DashboardModel
        do {
            let store = try PolarDatabase.onDisk()
            openedStore = store
            // HERC-050/051: build the config-driven engine from the authenticated
            // clients + the *same* store instance (registry upserts via `StoreWriting`,
            // engine reads/records via `SyncStore`) and inject it as the coordinator.
            let clients = auth.makeDataClients()
            let engine = SyncEngine(
                descriptors: SyncRegistry.standard(clients: clients, store: store),
                store: store,
                now: { Date() }
            )
            model = DashboardModel(coordinator: engine)
            #if DEBUG
            print("[Hercules] PolarStore opened at Application Support/\(PolarDatabase.defaultFilename)")
            #endif
        } catch {
            // A failed open leaves the app in its pre-sync (stub) state rather than
            // crashing; the dashboard falls back to the no-network stub coordinator.
            openedStore = nil
            model = DashboardModel()
            print("[Hercules] PolarStore failed to open: \(error)")
        }
        self.store = openedStore
        _auth = State(initialValue: auth)
        _dashboard = State(initialValue: model)
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
