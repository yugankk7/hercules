import SwiftUI
import HerculesUI
import PolarStore

@main
struct HerculesApp: App {

    init() {
        // HERC-002 sanity check: confirm the GRDB store wires up at launch.
        #if DEBUG
        let ok = PolarDatabase.selfTest()
        print("[Hercules] PolarStore self-test: \(ok ? "ok" : "FAILED")")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HerculesRootView()
                // HERC-001: hercules://oauth/callback opens the app.
                // The OAuth flow (EPIC 1) consumes this; for now we just log it.
                .onOpenURL { url in
                    print("[Hercules] opened via URL: \(url.absoluteString)")
                }
        }
    }
}
