import SwiftUI
import PolarProtocol

/// The connected-state navigation shell: a four-tab bar tinted `Theme.accent`.
/// Home hosts the dashboard feed; Trends/Workouts are labelled placeholders;
/// Profile hosts sign-out. This is the public entry point `HerculesUI` exposes
/// for the app router, rendered in place of the old `HerculesRootView`.
public struct RootTabView: View {
    private let auth: AuthManager
    private let dashboard: DashboardModel

    public init(auth: AuthManager, dashboard: DashboardModel) {
        self.auth = auth
        self.dashboard = dashboard
    }

    public var body: some View {
        TabView {
            DashboardView(model: dashboard)
                .tabItem { Label("HOME", systemImage: "square.grid.2x2") }

            PlaceholderTabView("TRENDS")
                .tabItem { Label("TRENDS", systemImage: "chart.xyaxis.line") }

            PlaceholderTabView("WORKOUTS")
                .tabItem { Label("WORKOUTS", systemImage: "figure.run") }

            ProfileView(auth: auth)
                .tabItem { Label("PROFILE", systemImage: "person") }
        }
        .tint(Theme.accent)
    }
}
