import Foundation

/// Display model for the **Boost From Sleep** screen (the `Boost From Sleep.dc.html`
/// design). A flat, UI-visible value type assembled by a `BoostDetailProviding`
/// from the merged `sleepwise_day` store, zero network. Lives in `PolarProtocol`
/// so the UI renders it without importing the store (mirrors `SleepDetail`). The
/// `state` carries the four render modes — the provider never returns `nil`.
public struct BoostDetail: Sendable, Equatable {
    /// `"TODAY"` / `"YESTERDAY"` / weekday.
    public let title: String
    /// `"WED · 23 JUN"` style sublabel.
    public let dateLabel: String
    public let state: BoostState
    /// Boost grade 0–10 (a `Double`, e.g. `8.1`), `nil` in calibrating/no-data.
    public let grade: Double?
    public let classification: GradeClass?
    /// Hourly boost bars positioned by their **own** `start`/`end` (partial edge
    /// buckets included), fractional local hours.
    public let hourly: [BoostBar]
    /// Preferred sleep window in fractional local hours.
    public let window: ClosedRange<Double>?
    /// Sleep **gate** — a range, not a point — in fractional local hours.
    public let gate: ClosedRange<Double>?
    public let inertia: SleepInertia?
    public let nightsLogged: Int
    public let calibrationTarget: Int

    public init(
        title: String, dateLabel: String, state: BoostState, grade: Double?,
        classification: GradeClass?, hourly: [BoostBar], window: ClosedRange<Double>?,
        gate: ClosedRange<Double>?, inertia: SleepInertia?, nightsLogged: Int,
        calibrationTarget: Int
    ) {
        self.title = title
        self.dateLabel = dateLabel
        self.state = state
        self.grade = grade
        self.classification = classification
        self.hourly = hourly
        self.window = window
        self.gate = gate
        self.inertia = inertia
        self.nightsLogged = nightsLogged
        self.calibrationTarget = calibrationTarget
    }

    /// The no-data representation (band not worn) — never a zeroed forecast.
    public static func noData(title: String, dateLabel: String,
                              nightsLogged: Int = 0, calibrationTarget: Int = 14) -> BoostDetail {
        BoostDetail(
            title: title, dateLabel: dateLabel, state: .noData, grade: nil, classification: nil,
            hourly: [], window: nil, gate: nil, inertia: nil,
            nightsLogged: nightsLogged, calibrationTarget: calibrationTarget
        )
    }

    /// A neutral placeholder for the VM's initial (pre-load) state.
    public static let placeholder = BoostDetail.noData(title: "BOOST", dateLabel: "")
}

/// How the Boost screen renders. Two distinct confidence signals (verified live
/// 2026-07-01): `calibrating` is gated on a logged-nights count (fresh user),
/// while `provisional` is per-night API confidence (`validity == ESTIMATE`,
/// interpolated across a data gap).
public enum BoostState: Sendable, Equatable {
    case forecast
    case provisional
    case calibrating
    case noData
}

/// One hourly boost bar, positioned by its own span (partial edges kept).
public struct BoostBar: Sendable, Equatable, Identifiable {
    /// Fractional local hour of the bucket start.
    public let start: Double
    public let end: Double
    /// Ramp index 0…4 into `Theme.zoneRamp`.
    public let level: Int
    /// `true` when this bucket's `validity == ESTIMATE` (interpolated).
    public let isEstimate: Bool

    public var id: Double { start }

    public init(start: Double, end: Double, level: Int, isEstimate: Bool) {
        self.start = start
        self.end = end
        self.level = level
        self.isEstimate = isEstimate
    }
}

/// Reads the Boost model. Local-first and non-throwing; `detail(for:)` always
/// returns a `BoostDetail` whose `state` carries `.noData`/`.calibrating`.
public protocol BoostDetailProviding: Sendable {
    /// SleepWise night dates (`YYYY-MM-DD`), most-recent first. Empty when none.
    func availableDays() async -> [String]
    /// The Boost detail for one night — always a value, never `nil`.
    func detail(for date: String) async -> BoostDetail
}

/// Synthesises the three render states so previews and the no-store fallback
/// render the full screen. Replaced by the `PolarStore`-backed provider.
public struct StubBoostDetailProvider: BoostDetailProviding {
    public init() {}

    private static let days = ["2026-06-23", "2026-06-22", "2026-06-21"]

    public func availableDays() async -> [String] { Self.days }

    public func detail(for date: String) async -> BoostDetail {
        switch date {
        case "2026-06-23": .sample(title: "YESTERDAY", dateLabel: "WED · 23 JUN", state: .forecast)
        case "2026-06-22": .sample(title: "TUE", dateLabel: "TUE · 22 JUN", state: .provisional)
        default:           .calibrating(title: "MON", dateLabel: "MON · 21 JUN", nightsLogged: 4)
        }
    }
}

public extension BoostDetail {
    /// A calibrating night (fresh user) — grade withheld, counter shown.
    static func calibrating(title: String, dateLabel: String, nightsLogged: Int,
                            calibrationTarget: Int = 14) -> BoostDetail {
        BoostDetail(
            title: title, dateLabel: dateLabel, state: .calibrating, grade: nil, classification: nil,
            hourly: [], window: nil, gate: nil, inertia: nil,
            nightsLogged: nightsLogged, calibrationTarget: calibrationTarget
        )
    }

    /// A representative forecast/provisional night matching the design mock.
    static func sample(title: String = "YESTERDAY", dateLabel: String = "WED · 23 JUN",
                       state: BoostState = .forecast) -> BoostDetail {
        // Waking day 10:00 → 22:00, alertness dipping mid-afternoon.
        let bars = stride(from: 10.0, to: 22.0, by: 1).map { h -> BoostBar in
            let level = h < 12 ? 4 : h < 16 ? 2 : h < 19 ? 1 : 2
            return BoostBar(start: h, end: h + 1, level: level, isEstimate: state == .provisional)
        }
        return BoostDetail(
            title: title, dateLabel: dateLabel, state: state, grade: 6.1, classification: .fair,
            hourly: bars, window: 2.88...10.2, gate: 2.0...2.5, inertia: .mild,
            nightsLogged: 28, calibrationTarget: 14
        )
    }
}
