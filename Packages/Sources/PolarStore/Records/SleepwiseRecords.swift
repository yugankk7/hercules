import Foundation
import GRDB
import PolarProtocol

/// `sleepwise_day` — one merged alertness + circadian night keyed by wake-day
/// (`sleep_period_end_time`, localised via the alertness offset). Enums are
/// persisted as their canonical tokens; the hourly buckets as JSON; gate/window
/// as raw UTC datetimes (localised to fractional hours at read time). Shapes
/// follow the live SleepWise capture (2026-07-01), not `ARCHITECTURE.md`
/// (Safeguard 10). The circadian offset is intentionally not stored — it is
/// unreliable, so a single alertness-derived offset localises the whole night.
struct SleepwiseDayRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "sleepwise_day"

    let date: String
    let grade: Double?
    let classification: String?
    let validity: String?
    let sleepInertia: String?
    let hourlyJson: String
    let gateStart: Date?
    let gateEnd: Date?
    let windowStart: Date?
    let windowEnd: Date?
    let quality: String?
    let tzOffsetMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case date, grade, classification, validity
        case sleepInertia = "sleep_inertia"
        case hourlyJson = "hourly_json"
        case gateStart = "gate_start"
        case gateEnd = "gate_end"
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case quality
        case tzOffsetMinutes = "tz_offset_minutes"
    }

    /// Merge one night's available fields — either side may be absent (degrade
    /// per-field). The offset is the alertness entry's, falling back to the
    /// batch-wide offset for a circadian-only night.
    init(date: String, alertness: Alertness?, circadian: CircadianBedtime?, fallbackOffset: Int) throws {
        self.date = date
        grade = alertness?.grade
        classification = alertness?.classification.token
        validity = alertness?.validity.token
        sleepInertia = alertness?.inertia.token
        let hours = (alertness?.hourlyData ?? []).map { AlertnessHourDTO($0) }
        hourlyJson = try StoreJSON.encode(hours)
        gateStart = circadian?.gateStart
        gateEnd = circadian?.gateEnd
        windowStart = circadian?.windowStart
        windowEnd = circadian?.windowEnd
        quality = circadian?.quality.token
        tzOffsetMinutes = alertness?.tzOffsetMinutes ?? fallbackOffset
    }

    func toView() throws -> SleepwiseDayView {
        let hourly = try StoreJSON.decode([AlertnessHourDTO].self, from: hourlyJson).map { $0.toModel() }
        let offset = tzOffsetMinutes ?? 0
        return SleepwiseDayView(
            date: date,
            grade: grade,
            classification: classification.map(GradeClass.parse),
            validity: validity.map(Validity.parse) ?? .unknown(""),
            inertia: sleepInertia.map(SleepInertia.parse),
            hourly: hourly,
            gate: Self.range(gateStart, gateEnd, offset: offset),
            window: Self.range(windowStart, windowEnd, offset: offset),
            quality: quality.map(BedtimeQuality.parse),
            tzOffsetMinutes: offset
        )
    }

    /// A pair of UTC datetimes → fractional local-hour range (wrapping past
    /// midnight extends the upper bound past 24 so the range stays ascending).
    private static func range(_ lower: Date?, _ upper: Date?, offset: Int) -> ClosedRange<Double>? {
        guard let lower, let upper else { return nil }
        let lo = localHour(lower, offset)
        let hiRaw = localHour(upper, offset)
        let hi = hiRaw < lo ? hiRaw + 24 : hiRaw
        return lo...hi
    }

    /// Fractional local hour [0,24) for a UTC date shifted by `offset` minutes.
    private static func localHour(_ date: Date, _ offset: Int) -> Double {
        let secs = date.timeIntervalSince1970 + Double(offset) * 60
        let inDay = secs.truncatingRemainder(dividingBy: 86_400)
        return (inDay < 0 ? inDay + 86_400 : inDay) / 3600
    }
}
