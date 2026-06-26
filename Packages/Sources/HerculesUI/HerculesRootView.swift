import SwiftUI
import PolarProtocol

/// Placeholder root view for the EPIC-0 scaffold. Real screens (Dashboard,
/// detail screens, the Hercules design system) land in later epics — see
/// `SCREENS_AND_FEATURES.md` and `CLAUDE.md` (the design system).
///
/// Styled loosely to the instrument aesthetic (pure-black canvas, orange
/// accent, monospace) so the empty app already reads as Hercules.
public struct HerculesRootView: View {

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                Text("HERCULES")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(Color(red: 0.996, green: 0.498, blue: 0.176)) // #FE7F2D

                Text("TELEMETRY")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color(red: 0.369, green: 0.447, blue: 0.502)) // #5E7280

                Text("FOUNDATION READY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 8)
            }
        }
    }
}

#Preview {
    HerculesRootView()
}
