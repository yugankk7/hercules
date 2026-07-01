import Foundation

/// Display model for the **Sleep Detail** day view (the `Sleep Detail.dc.html`
/// design, "01 · DAY VIEW"). A flat, UI-visible value type — assembled by a
/// `SleepDetailProviding` from the local `sleep_night` store, then handed to
/// `HerculesUI` for geometry/formatting. Lives in `PolarProtocol` (not
/// `PolarStore`) so the UI renders it without importing the store — the exact
/// analogue of `ActivityDetail`.
public struct SleepDetail: Sendable, Equatable {
    /// `"TODAY"` for the current UTC night, else the weekday (`"THU"`).
    public let title: String
    /// `"THU · 25 JUN"` style sublabel.
    public let dateLabel: String

    public let score: Int?
    public let cycles: Int
    public let continuity: Double?
    public let continuityClass: Int?

    /// The four stage totals in fixed REM/LIGHT/DEEP/AWAKE order, each with its
    /// minutes and a ramp level — always four entries so the legend renders
    /// without branching.
    public let stages: [SleepStageBar]
    /// Ordered hypnogram segments derived from the `"HH:MM"`→stage map, anchored
    /// on the night window (sorted ascending by `startHour`, may cross 24h).
    public let hypnogram: [HypnogramSegment]
    /// Per-sample HR positioned on the night axis; empty when HR hasn't synced
    /// (the curve then degrades to the hypnogram band alone).
    public let hr: [SleepHRSample]
    /// Fractional-hour sleep window (anchored on `startTime`/`endTime`; the upper
    /// bound may exceed 24 for a night that crosses midnight).
    public let window: ClosedRange<Double>
    /// How the night's amount compares to the usual bracket (below/on/above).
    public let amount: AmountBracket
    /// True when the night has no server row → "NO RECORD / NO TELEMETRY".
    public let isEmpty: Bool

    public init(
        title: String, dateLabel: String, score: Int?, cycles: Int,
        continuity: Double?, continuityClass: Int?, stages: [SleepStageBar],
        hypnogram: [HypnogramSegment], hr: [SleepHRSample],
        window: ClosedRange<Double>, amount: AmountBracket, isEmpty: Bool
    ) {
        self.title = title
        self.dateLabel = dateLabel
        self.score = score
        self.cycles = cycles
        self.continuity = continuity
        self.continuityClass = continuityClass
        self.stages = stages
        self.hypnogram = hypnogram
        self.hr = hr
        self.window = window
        self.amount = amount
        self.isEmpty = isEmpty
    }

    /// Total recorded sleep minutes (REM + LIGHT + DEEP — excludes AWAKE).
    public var asleepMinutes: Int {
        stages.filter { $0.stage != .wake }.reduce(0) { $0 + $1.minutes }
    }

    /// The absent-night representation — never a zeroed screen (Safeguard 3).
    /// The window defaults to a 22:00→10:00 span so the empty hypnogram axis
    /// still renders its clock ticks (matching the design's "03 · NO TELEMETRY").
    public static func empty(title: String, dateLabel: String) -> SleepDetail {
        SleepDetail(
            title: title, dateLabel: dateLabel, score: nil, cycles: 0,
            continuity: nil, continuityClass: nil,
            stages: SleepStageBar.emptySet, hypnogram: [], hr: [],
            window: 22...34, amount: .on, isEmpty: true
        )
    }
}

/// One stage total of the night (REM/LIGHT/DEEP/AWAKE) for the breakdown legend.
public struct SleepStageBar: Sendable, Equatable, Identifiable {
    public let stage: SleepStage
    public let minutes: Int

    public var id: SleepStage { stage }
    public var name: String { stage.label }
    /// Ramp index 0…4 into `Theme.zoneRamp` (the data-encoding colour scale).
    public var level: Int { stage.rampLevel }

    public init(stage: SleepStage, minutes: Int) {
        self.stage = stage
        self.minutes = minutes
    }

    /// The four stage bars in the fixed legend order, minutes zeroed — the base
    /// for both the empty state and the "derive from totals" path.
    public static var emptySet: [SleepStageBar] {
        [.init(stage: .rem, minutes: 0), .init(stage: .light, minutes: 0),
         .init(stage: .deep, minutes: 0), .init(stage: .wake, minutes: 0)]
    }
}

/// A sleep stage. Hypnogram codes are `0/1/3/4 = wake/REM/light/deep`
/// (`SleepModels`); code `2` is unused and any unknown code degrades to `.wake`.
public enum SleepStage: Int, Sendable, Equatable, CaseIterable {
    case wake, rem, light, deep

    /// Map a raw hypnogram code (`0/1/3/4`) to a stage.
    public init(code: Int) {
        switch code {
        case 1: self = .rem
        case 3: self = .light
        case 4: self = .deep
        default: self = .wake
        }
    }

    public var label: String {
        switch self {
        case .wake:  "AWAKE"
        case .rem:   "REM"
        case .light: "LIGHT"
        case .deep:  "DEEP"
        }
    }

    /// Vertical position in the hypnogram band, shallow→deep (0 = top/AWAKE).
    public var depth: Int {
        switch self {
        case .wake:  0
        case .rem:   1
        case .light: 2
        case .deep:  3
        }
    }

    /// Ramp index 0…4 into `Theme.zoneRamp` (deep sleep reads strongest).
    public var rampLevel: Int {
        switch self {
        case .wake:  0
        case .light: 1
        case .rem:   2
        case .deep:  4
        }
    }
}

/// A contiguous run of one stage on the night axis, in fractional hours.
public struct HypnogramSegment: Sendable, Equatable {
    public let startHour: Double
    public let endHour: Double
    public let stage: SleepStage

    public init(startHour: Double, endHour: Double, stage: SleepStage) {
        self.startHour = startHour
        self.endHour = endHour
        self.stage = stage
    }
}

/// One HR reading positioned on the night axis (fractional hour, may exceed 24).
public struct SleepHRSample: Sendable, Equatable {
    public let hour: Double
    public let bpm: Int

    public init(hour: Double, bpm: Int) {
        self.hour = hour
        self.bpm = bpm
    }
}

/// How the night's sleep amount sits against the usual bracket (design's
/// "MUCH BELOW USUAL" caption). A display bracket, not a clinical judgement.
public enum AmountBracket: Sendable, Equatable {
    case below, on, above

    public var caption: String {
        switch self {
        case .below: "MUCH BELOW USUAL"
        case .on:    "AROUND USUAL"
        case .above: "ABOVE USUAL"
        }
    }
}

/// Reads the sleep-detail model. Local-first and non-throwing (mirrors
/// `ActivityDetailProviding`): the screen swipes between stored nights, so it
/// needs the list of nights plus per-night day detail and a per-night week
/// aggregate. `nil`/empty means no night recorded.
public protocol SleepDetailProviding: Sendable {
    /// Sleep-night dates (`YYYY-MM-DD`), most-recent first. Empty when none.
    func availableDays() async -> [String]
    /// Day detail for one night, or `nil` if that date has no night.
    func detail(for date: String) async -> SleepDetail?
    /// The 7-night aggregate ending at `date`, or `nil` when the window is empty.
    func week(endingAt date: String) async -> SleepWeekDetail?
}

/// Synthesises a handful of plausible nights so previews and the no-store
/// fallback render the full screen (day + week swipe). Replaced by the
/// `PolarStore`-backed provider.
public struct StubSleepDetailProvider: SleepDetailProviding {
    public init() {}

    private static let days = [
        "2026-06-25", "2026-06-24", "2026-06-23", "2026-06-22",
        "2026-06-21", "2026-06-20", "2026-06-19",
    ]

    public func availableDays() async -> [String] { Self.days }

    public func detail(for date: String) async -> SleepDetail? {
        switch date {
        case "2026-06-25": .sample(title: "TODAY", dateLabel: "THU · 25 JUN", score: 41, cycles: 5)
        case "2026-06-24": .sample(title: "WED", dateLabel: "WED · 24 JUN", score: 68, cycles: 6)
        default:           .sample(title: "TUE", dateLabel: "TUE · 23 JUN", score: 74, cycles: 5)
        }
    }

    public func week(endingAt date: String) async -> SleepWeekDetail? {
        .sample(rangeLabel: "JUN 19–25")
    }
}

public extension SleepDetail {
    /// A representative night matching the design mock, parameterised so the stub
    /// can vary it across the swipe days.
    static func sample(
        title: String = "TODAY", dateLabel: String = "THU · 25 JUN",
        score: Int = 41, cycles: Int = 5
    ) -> SleepDetail {
        // A night 3:23 AM → 10:04 AM (fractional 3.38 → 10.07).
        let start = 3.38, end = 10.07
        let stageOrder: [SleepStage] = [.light, .deep, .rem, .light, .wake, .light, .rem, .deep, .light, .rem]
        let step = (end - start) / Double(stageOrder.count)
        let hypnogram = stageOrder.enumerated().map { i, stage in
            HypnogramSegment(startHour: start + Double(i) * step,
                             endHour: start + Double(i + 1) * step, stage: stage)
        }
        let hr = stride(from: start, through: end, by: 0.25).map { h -> SleepHRSample in
            SleepHRSample(hour: h, bpm: Int((54 + 8 * sin((h - start) * 1.7)).rounded()))
        }
        return SleepDetail(
            title: title, dateLabel: dateLabel, score: score, cycles: cycles,
            continuity: 1.3, continuityClass: 2,
            stages: [
                SleepStageBar(stage: .rem, minutes: 88),
                SleepStageBar(stage: .light, minutes: 214),
                SleepStageBar(stage: .deep, minutes: 86),
                SleepStageBar(stage: .wake, minutes: 25),
            ],
            hypnogram: hypnogram, hr: hr, window: start...end, amount: .below, isEmpty: false
        )
    }
}
