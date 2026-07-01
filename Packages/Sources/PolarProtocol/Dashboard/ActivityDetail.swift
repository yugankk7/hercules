import Foundation

/// Display model for the **Daily Activity detail** screen (the `Daily Activity.dc.html`
/// design). A flat, UI-visible value type — assembled by an `ActivityDetailProviding`
/// from the local store, then handed to `HerculesUI` for geometry/formatting. Lives
/// in `PolarProtocol` (not `PolarStore`) so the UI can render it without importing the
/// store, mirroring `DashboardSnapshot`.
public struct ActivityDetail: Sendable, Equatable {
    /// `"TODAY"` for the current UTC day, else the weekday (`"TUE"`).
    public let title: String
    /// `"WED · JUN 25"` style sublabel.
    public let dateLabel: String

    public let steps: Int
    public let distanceKm: Double
    public let activeMinutes: Int
    public let calories: Int
    /// v3 `daily_activity` — the goal-completion percentage (may exceed 100).
    public let dailyActivityPct: Int
    public let inactivityCount: Int
    /// Total awake (non-sleep, worn) minutes — the sum of the zone slices.
    public let awakeMinutes: Int

    /// The five intensity slices in REST→HIGH order, each with its minutes and ramp
    /// level (0…4). Always five entries so the legend renders without branching.
    public let zones: [ActivityZoneSlice]
    /// Per-bucket intensity level (0…4) across the day for the density band —
    /// `intensity.count` buckets spanning 00:00→24:00 (0 = no bar / sleep / non-wear).
    public let intensity: [Int]
    /// Per-minute(ish) continuous-HR samples for the hero curve; empty when HR
    /// hasn't synced (the curve then degrades to the intensity band alone).
    public let hr: [ActivityHRSample]
    /// The night-sleep block carried past midnight, in fractional hours, if recognised.
    public let sleepBlock: ClosedRange<Double>?

    public init(
        title: String, dateLabel: String, steps: Int, distanceKm: Double,
        activeMinutes: Int, calories: Int, dailyActivityPct: Int, inactivityCount: Int,
        awakeMinutes: Int, zones: [ActivityZoneSlice], intensity: [Int],
        hr: [ActivityHRSample], sleepBlock: ClosedRange<Double>?
    ) {
        self.title = title
        self.dateLabel = dateLabel
        self.steps = steps
        self.distanceKm = distanceKm
        self.activeMinutes = activeMinutes
        self.calories = calories
        self.dailyActivityPct = dailyActivityPct
        self.inactivityCount = inactivityCount
        self.awakeMinutes = awakeMinutes
        self.zones = zones
        self.intensity = intensity
        self.hr = hr
        self.sleepBlock = sleepBlock
    }
}

/// One intensity-zone slice of the awake day (REST/SIT/LOW/MED/HIGH).
public struct ActivityZoneSlice: Sendable, Equatable, Identifiable {
    public let name: String
    /// Ramp index 0…4 → the data-encoding colour scale (CLAUDE.md palette).
    public let level: Int
    public let minutes: Int

    public var id: String { name }

    public init(name: String, level: Int, minutes: Int) {
        self.name = name
        self.level = level
        self.minutes = minutes
    }
}

/// One continuous-HR reading positioned on the 24h axis.
public struct ActivityHRSample: Sendable, Equatable {
    /// Fractional hour 0…24 (e.g. `18.5` = 6:30 PM).
    public let hour: Double
    public let bpm: Int

    public init(hour: Double, bpm: Int) {
        self.hour = hour
        self.bpm = bpm
    }
}

/// Reads the activity-detail model. Local-first and non-throwing (mirrors
/// `DashboardProviding`): the screen swipes between the stored days, so it needs both
/// the list of days and per-day detail. `nil`/empty means no activity recorded.
public protocol ActivityDetailProviding: Sendable {
    /// Dates (`YYYY-MM-DD`) that have activity, most-recent first. Empty when none.
    func availableDays() async -> [String]
    /// Detail for one day, or `nil` if that date has no activity.
    func detail(for date: String) async -> ActivityDetail?
}

/// Synthesises a few plausible days so previews and the no-store fallback render the
/// full screen (and its day-swipe). Replaced by the `PolarStore`-backed provider.
public struct StubActivityDetailProvider: ActivityDetailProviding {
    public init() {}

    private static let days = ["2026-06-25", "2026-06-24", "2026-06-23"]

    public func availableDays() async -> [String] { Self.days }

    public func detail(for date: String) async -> ActivityDetail? {
        switch date {
        case "2026-06-25": .sample(title: "TODAY", dateLabel: "WED · 25 JUN", steps: 4068, calories: 3174, pct: 90)
        case "2026-06-24": .sample(title: "TUE", dateLabel: "TUE · 24 JUN", steps: 8120, calories: 3540, pct: 118)
        default:           .sample(title: "MON", dateLabel: "MON · 23 JUN", steps: 5210, calories: 2980, pct: 74)
        }
    }
}

public extension ActivityDetail {
    /// A representative day matching the design mock, parameterised so the stub can
    /// vary it across the swipe days.
    static func sample(
        title: String = "TODAY", dateLabel: String = "WED · JUN 25",
        steps: Int = 4068, calories: Int = 3174, pct: Int = 90
    ) -> ActivityDetail {
        // A resting→active→evening-peak HR shape, sampled every 10 minutes.
        let controls: [(Double, Double)] = [
            (0, 49), (3, 47), (6.5, 50), (7.5, 70), (9, 80), (12, 84), (15, 80),
            (18, 92), (18.3, 128), (19.1, 158), (20, 86), (22, 62), (24, 51),
        ]
        func interp(_ hour: Double) -> Int {
            var a = controls[0], b = controls[controls.count - 1]
            for k in 0..<(controls.count - 1) where hour >= controls[k].0 && hour <= controls[k + 1].0 {
                a = controls[k]; b = controls[k + 1]; break
            }
            let span = (b.0 - a.0) == 0 ? 1 : (b.0 - a.0)
            let base = a.1 + (b.1 - a.1) * (hour - a.0) / span
            return Int((base + 2 * sin(hour * 1.9)).rounded())
        }
        let buckets = 144
        let hr = (0..<buckets).map { i -> ActivityHRSample in
            let hour = Double(i) / 6
            return ActivityHRSample(hour: hour, bpm: interp(hour))
        }
        let intensity = (0..<buckets).map { i -> Int in
            let hour = Double(i) / 6
            if hour < 6.2 { return 0 }                 // asleep
            if hour >= 18 && hour < 19.3 { return hour >= 18.9 ? 4 : 3 }
            if hour >= 7 && hour < 17 { return Int(1.5 + sin(hour) ).clampedRamp() }
            return 1
        }
        return ActivityDetail(
            title: title, dateLabel: dateLabel, steps: steps, distanceKm: Double(steps) / 1530,
            activeMinutes: 187, calories: calories, dailyActivityPct: pct, inactivityCount: 3,
            awakeMinutes: 1130,
            zones: [
                ActivityZoneSlice(name: "REST", level: 0, minutes: 0),
                ActivityZoneSlice(name: "SIT", level: 1, minutes: 399),
                ActivityZoneSlice(name: "LOW", level: 2, minutes: 594),
                ActivityZoneSlice(name: "MED", level: 3, minutes: 83),
                ActivityZoneSlice(name: "HIGH", level: 4, minutes: 54),
            ],
            intensity: intensity, hr: hr, sleepBlock: 0...6.18
        )
    }
}

private extension Int {
    func clampedRamp() -> Int { Swift.max(0, Swift.min(4, self)) }
}
