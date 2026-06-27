import Foundation

/// Identifies each dashboard domain and carries its presentation metadata.
/// `CaseIterable` order **is** the default home-feed order (Operations) — the
/// single source of truth for the feed, so adding a future card is localized.
public enum CardKind: String, Sendable, CaseIterable, Identifiable {
    case dailyActivity
    case sleep
    case nightlyRecharge
    case cardioLoad
    case boostFromSleep
    case continuousHR
    case latestWorkout
    case deviceGlance

    public var id: CardKind { self }

    /// Single-letter instrument glyph rendered in the card's slate tile.
    public var glyph: String {
        switch self {
        case .dailyActivity:   "A"
        case .sleep:           "Z"
        case .nightlyRecharge: "R"
        case .cardioLoad:      "C"
        case .boostFromSleep:  "B"
        case .continuousHR:    "H"
        case .latestWorkout:   "W"
        case .deviceGlance:    "D"
        }
    }

    /// Tracked monospace card title.
    public var title: String {
        switch self {
        case .dailyActivity:   "DAILY ACTIVITY"
        case .sleep:           "SLEEP"
        case .nightlyRecharge: "NIGHTLY RECHARGE"
        case .cardioLoad:      "CARDIO LOAD"
        case .boostFromSleep:  "BOOST FROM SLEEP"
        case .continuousHR:    "CONTINUOUS HR"
        case .latestWorkout:   "LATEST WORKOUT"
        case .deviceGlance:    "DEVICE"
        }
    }
}
