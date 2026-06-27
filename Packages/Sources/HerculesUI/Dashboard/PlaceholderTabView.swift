import SwiftUI

/// A labelled placeholder for tabs whose features land later (Trends, Workouts):
/// a centered instrument-styled empty state — tracked mono title + `COMING SOON`
/// sublabel on the black canvas.
struct PlaceholderTabView: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Text(title)
                    .font(Theme.mono(22, .heavy))
                    .tracking(2)
                    .foregroundStyle(Theme.text)
                Text("COMING SOON")
                    .font(Theme.mono(9, .semibold))
                    .tracking(3)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}
