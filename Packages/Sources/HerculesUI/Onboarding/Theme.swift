import SwiftUI

/// Hercules instrument design tokens — palette + Azeret-Mono type (see `CLAUDE.md`).
/// Precision-instrument aesthetic: pure-black canvas, orange spotlight, monospace.
public enum Theme {
    // Core
    public static let background = Color.black                                  // #000000
    public static let accent = Color(red: 0.996, green: 0.498, blue: 0.176)     // #FE7F2D
    public static let slate = Color(red: 0.137, green: 0.239, blue: 0.302)      // #233D4D
    public static let text = Color(red: 0.918, green: 0.925, blue: 0.941)       // #EAECF0

    // Extended
    public static let card = Color(red: 0.055, green: 0.106, blue: 0.133)       // #0E1B22
    public static let cardBorder = Color(red: 0.106, green: 0.176, blue: 0.220) // #1B2D38
    public static let hairline = Color(red: 0.086, green: 0.141, blue: 0.173)   // #16242C
    public static let muted = Color(red: 0.369, green: 0.447, blue: 0.502)      // #5E7280
    public static let faint = Color(red: 0.227, green: 0.318, blue: 0.376)      // #3A5160
    public static let panelDark = Color(red: 0.027, green: 0.059, blue: 0.075)  // #070F13
    public static let grid = Color(red: 0.075, green: 0.137, blue: 0.169)       // #13232B

    /// Data-encoding intensity ramp (REST→HIGH), used for zone bars / density lines
    /// (CLAUDE.md palette). Index 0…4 maps low→high.
    public static let zoneRamp: [Color] = [
        Color(red: 0.165, green: 0.259, blue: 0.325), // #2A4253 REST
        Color(red: 0.227, green: 0.318, blue: 0.376), // #3A5160 SIT
        Color(red: 0.369, green: 0.447, blue: 0.502), // #5E7280 LOW
        Color(red: 0.878, green: 0.475, blue: 0.227), // #E0793A MED
        Color(red: 0.996, green: 0.498, blue: 0.176), // #FE7F2D HIGH
    ]

    /// Azeret Mono isn't bundled yet — fall back to the system monospaced face,
    /// which preserves the tabular-figure behaviour the design depends on.
    public static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
