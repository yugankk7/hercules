import SwiftUI

/// Full-width primary pill CTA — orange fill, black 800-weight label, +2px
/// tracking, 56pt tall (see `CLAUDE.md` Components).
struct PrimaryCTA: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(14, .heavy))
                .tracking(2)
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
