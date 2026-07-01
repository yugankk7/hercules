import Foundation

/// SleepWise wire models (Epic 9 / HERC-090..091). Shapes **verified against a
/// live capture (2026-07-01)**: both `/v3/users/sleepwise/alertness/date` and
/// `/circadian-bedtime/date` return a **top-level array of ~28 night-entries** in
/// one call (like `/cardio-load`), carry **no `date` field** (key on
/// `sleep_period_end_time`), report `grade` as a **`Double`**, and encode
/// classification/inertia/quality/level/validity as **prefixed enum strings**.
/// Timestamps are UTC-naive; add `sleep_timezone_offset_minutes` to reach local
/// wall-clock. Decode-only, tolerant `decodeIfPresent` (Norm 6).

// MARK: - Enums (prefix-stripping, tolerant)

/// Alertness grade band (`GRADE_CLASSIFICATION_FAIR/WEAK/GOOD/…`). Matched by
/// suffix so the same parser handles the wire value and the stored token.
public enum GradeClass: Sendable, Equatable, Decodable {
    case excellent, good, fair, weak, unknown(String)

    public static func parse(_ raw: String) -> GradeClass {
        let u = raw.uppercased()
        if u.hasSuffix("EXCELLENT") { return .excellent }
        if u.hasSuffix("GOOD") { return .good }
        if u.hasSuffix("FAIR") { return .fair }
        if u.hasSuffix("WEAK") { return .weak }
        return .unknown(raw)
    }

    /// Canonical short token, for `sleepwise_day` storage.
    public var token: String {
        switch self {
        case .excellent: "EXCELLENT"
        case .good: "GOOD"
        case .fair: "FAIR"
        case .weak: "WEAK"
        case .unknown(let raw): raw
        }
    }

    /// Display label (`"FAIR"`).
    public var label: String { token }

    public init(from decoder: any Decoder) throws {
        self = .parse(try decoder.singleValueContainer().decode(String.self))
    }
}

/// Per-entry confidence (`VALIDITY_VALID/ESTIMATE`). `ESTIMATE` = interpolated
/// across a data gap → render provisional, never hidden.
public enum Validity: Sendable, Equatable, Decodable {
    case valid, estimate, unknown(String)

    public static func parse(_ raw: String) -> Validity {
        let u = raw.uppercased()
        if u.hasSuffix("ESTIMATE") { return .estimate }
        if u.hasSuffix("VALID") { return .valid }
        return .unknown(raw)
    }

    public var token: String {
        switch self {
        case .valid: "VALID"
        case .estimate: "ESTIMATE"
        case .unknown(let raw): raw
        }
    }

    public init(from decoder: any Decoder) throws {
        self = .parse(try decoder.singleValueContainer().decode(String.self))
    }
}

/// Morning sleep-inertia band (`SLEEP_INERTIA_NO_INERTIA/MILD/MODERATE`). An
/// **enum, not minutes** (verified live). `NO_INERTIA` checked before `INERTIA`.
public enum SleepInertia: Sendable, Equatable, Decodable {
    case noInertia, mild, moderate, severe, unknown(String)

    public static func parse(_ raw: String) -> SleepInertia {
        let u = raw.uppercased()
        if u.hasSuffix("NO_INERTIA") { return .noInertia }
        if u.hasSuffix("MODERATE") { return .moderate }
        if u.hasSuffix("SEVERE") { return .severe }
        if u.hasSuffix("MILD") { return .mild }
        return .unknown(raw)
    }

    public var token: String {
        switch self {
        case .noInertia: "NO_INERTIA"
        case .mild: "MILD"
        case .moderate: "MODERATE"
        case .severe: "SEVERE"
        case .unknown(let raw): raw
        }
    }

    /// Display label (`"MILD"`, `"NONE"`).
    public var label: String {
        switch self {
        case .noInertia: "NONE"
        case .mild: "MILD"
        case .moderate: "MODERATE"
        case .severe: "SEVERE"
        case .unknown(let raw): raw
        }
    }

    public init(from decoder: any Decoder) throws {
        self = .parse(try decoder.singleValueContainer().decode(String.self))
    }
}

/// Hourly alertness bucket level (`ALERTNESS_LEVEL_HIGH/LOW/VERY_LOW/MINIMAL`).
/// `VERY_LOW` checked before `LOW`.
public enum AlertnessLevel: Sendable, Equatable, Decodable {
    case high, low, veryLow, minimal, unknown(String)

    public static func parse(_ raw: String) -> AlertnessLevel {
        let u = raw.uppercased()
        if u.hasSuffix("VERY_LOW") { return .veryLow }
        if u.hasSuffix("MINIMAL") { return .minimal }
        if u.hasSuffix("HIGH") { return .high }
        if u.hasSuffix("LOW") { return .low }
        return .unknown(raw)
    }

    public var token: String {
        switch self {
        case .high: "HIGH"
        case .low: "LOW"
        case .veryLow: "VERY_LOW"
        case .minimal: "MINIMAL"
        case .unknown(let raw): raw
        }
    }

    /// Ramp index 0…4 into the shared intensity palette (high alertness reads hot).
    public var rampLevel: Int {
        switch self {
        case .high: 4
        case .low: 2
        case .veryLow: 1
        case .minimal: 0
        case .unknown: 0
        }
    }

    public init(from decoder: any Decoder) throws {
        self = .parse(try decoder.singleValueContainer().decode(String.self))
    }
}

/// Circadian bedtime-quality band (`CIRCADIAN_BEDTIME_QUALITY_CLEARLY_RECOGNIZABLE/…`).
public enum BedtimeQuality: Sendable, Equatable, Decodable {
    case clearlyRecognizable, recognizable, weaklyRecognizable, unknown(String)

    public static func parse(_ raw: String) -> BedtimeQuality {
        let u = raw.uppercased()
        if u.hasSuffix("CLEARLY_RECOGNIZABLE") { return .clearlyRecognizable }
        if u.hasSuffix("WEAKLY_RECOGNIZABLE") { return .weaklyRecognizable }
        if u.hasSuffix("RECOGNIZABLE") { return .recognizable }
        return .unknown(raw)
    }

    public var token: String {
        switch self {
        case .clearlyRecognizable: "CLEARLY_RECOGNIZABLE"
        case .recognizable: "RECOGNIZABLE"
        case .weaklyRecognizable: "WEAKLY_RECOGNIZABLE"
        case .unknown(let raw): raw
        }
    }

    public init(from decoder: any Decoder) throws {
        self = .parse(try decoder.singleValueContainer().decode(String.self))
    }
}

// MARK: - Day-key derivation

/// The wake-morning day key (`YYYY-MM-DD`) for a UTC timestamp shifted by
/// `offsetMinutes` — the SleepWise join key + `sleepwise_day` PK. Manually shifts
/// then formats in UTC (the times are UTC-naive; the offset reaches local
/// wall-clock).
public enum SleepWiseDayKey {
    public static func string(from utc: Date, offsetMinutes: Int) -> String {
        let local = utc.addingTimeInterval(Double(offsetMinutes) * 60)
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .gmt
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: local)
    }
}

// MARK: - Alertness

/// One element of `GET /v3/users/sleepwise/alertness/date` (`[Alertness]`).
public struct Alertness: Decodable, Sendable, Equatable {
    public let periodStart: Date
    public let periodEnd: Date
    public let sleepPeriodStart: Date
    public let sleepPeriodEnd: Date
    /// The **authoritative** offset for the night — applied to both series
    /// (circadian's own offset is unreliable, capture 2026-07-01).
    public let tzOffsetMinutes: Int
    public let grade: Double
    public let classification: GradeClass
    public let validity: Validity
    public let inertia: SleepInertia
    public let hourlyData: [AlertnessHour]

    enum CodingKeys: String, CodingKey {
        case periodStart = "period_start_time"
        case periodEnd = "period_end_time"
        case sleepPeriodStart = "sleep_period_start_time"
        case sleepPeriodEnd = "sleep_period_end_time"
        case tzOffsetMinutes = "sleep_timezone_offset_minutes"
        case grade
        case classification = "grade_classification"
        case validity
        case inertia = "sleep_inertia"
        case hourlyData = "hourly_data"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        periodStart = try c.decodeIfPresent(Date.self, forKey: .periodStart) ?? .distantPast
        periodEnd = try c.decodeIfPresent(Date.self, forKey: .periodEnd) ?? .distantPast
        sleepPeriodStart = try c.decodeIfPresent(Date.self, forKey: .sleepPeriodStart) ?? .distantPast
        sleepPeriodEnd = try c.decodeIfPresent(Date.self, forKey: .sleepPeriodEnd) ?? .distantPast
        tzOffsetMinutes = try c.decodeIfPresent(Int.self, forKey: .tzOffsetMinutes) ?? 0
        grade = try c.decodeIfPresent(Double.self, forKey: .grade) ?? 0
        classification = try c.decodeIfPresent(GradeClass.self, forKey: .classification) ?? .unknown("")
        validity = try c.decodeIfPresent(Validity.self, forKey: .validity) ?? .unknown("")
        inertia = try c.decodeIfPresent(SleepInertia.self, forKey: .inertia) ?? .unknown("")
        hourlyData = try c.decodeIfPresent([AlertnessHour].self, forKey: .hourlyData) ?? []
    }

    public init(
        periodStart: Date, periodEnd: Date, sleepPeriodStart: Date, sleepPeriodEnd: Date,
        tzOffsetMinutes: Int, grade: Double, classification: GradeClass, validity: Validity,
        inertia: SleepInertia, hourlyData: [AlertnessHour]
    ) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.sleepPeriodStart = sleepPeriodStart
        self.sleepPeriodEnd = sleepPeriodEnd
        self.tzOffsetMinutes = tzOffsetMinutes
        self.grade = grade
        self.classification = classification
        self.validity = validity
        self.inertia = inertia
        self.hourlyData = hourlyData
    }

    /// The wake-day key (`YYYY-MM-DD` of `sleepPeriodEnd`, localised with this
    /// night's own offset) — the join key + `sleepwise_day` PK.
    public func wakeDayKey() -> String {
        SleepWiseDayKey.string(from: sleepPeriodEnd, offsetMinutes: tzOffsetMinutes)
    }
}

/// One hourly alertness bucket. First/last buckets may span < 1h (partial edges),
/// so callers position by the bucket's own `start`/`end`, not a fixed 24-grid.
public struct AlertnessHour: Decodable, Sendable, Equatable {
    public let start: Date
    public let end: Date
    public let level: AlertnessLevel
    public let validity: Validity

    enum CodingKeys: String, CodingKey {
        case start = "start_time"
        case end = "end_time"
        case level = "alertness_level"
        case validity
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = try c.decodeIfPresent(Date.self, forKey: .start) ?? .distantPast
        end = try c.decodeIfPresent(Date.self, forKey: .end) ?? .distantPast
        level = try c.decodeIfPresent(AlertnessLevel.self, forKey: .level) ?? .unknown("")
        validity = try c.decodeIfPresent(Validity.self, forKey: .validity) ?? .unknown("")
    }

    public init(start: Date, end: Date, level: AlertnessLevel, validity: Validity) {
        self.start = start
        self.end = end
        self.level = level
        self.validity = validity
    }
}

// MARK: - Circadian bedtime

/// One element of `GET /v3/users/sleepwise/circadian-bedtime/date`
/// (`[CircadianBedtime]`). The gate is a **range** (`sleep_gate_start/end_time`),
/// the window is `preferred_sleep_period_start/end_time`.
public struct CircadianBedtime: Decodable, Sendable, Equatable {
    public let periodStart: Date
    public let periodEnd: Date
    public let windowStart: Date?
    public let windowEnd: Date?
    public let gateStart: Date?
    public let gateEnd: Date?
    public let quality: BedtimeQuality
    public let validity: Validity
    /// This endpoint reports a **bogus `0`** offset while its times are UTC —
    /// callers ignore it and localise with the matched alertness night's offset.
    public let tzOffsetMinutes: Int

    enum CodingKeys: String, CodingKey {
        case periodStart = "period_start_time"
        case periodEnd = "period_end_time"
        case windowStart = "preferred_sleep_period_start_time"
        case windowEnd = "preferred_sleep_period_end_time"
        case gateStart = "sleep_gate_start_time"
        case gateEnd = "sleep_gate_end_time"
        case quality = "circadian_bedtime_quality"
        case validity
        case tzOffsetMinutes = "sleep_timezone_offset_minutes"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        periodStart = try c.decodeIfPresent(Date.self, forKey: .periodStart) ?? .distantPast
        periodEnd = try c.decodeIfPresent(Date.self, forKey: .periodEnd) ?? .distantPast
        windowStart = try c.decodeIfPresent(Date.self, forKey: .windowStart)
        windowEnd = try c.decodeIfPresent(Date.self, forKey: .windowEnd)
        gateStart = try c.decodeIfPresent(Date.self, forKey: .gateStart)
        gateEnd = try c.decodeIfPresent(Date.self, forKey: .gateEnd)
        quality = try c.decodeIfPresent(BedtimeQuality.self, forKey: .quality) ?? .unknown("")
        validity = try c.decodeIfPresent(Validity.self, forKey: .validity) ?? .unknown("")
        tzOffsetMinutes = try c.decodeIfPresent(Int.self, forKey: .tzOffsetMinutes) ?? 0
    }

    public init(
        periodStart: Date, periodEnd: Date, windowStart: Date?, windowEnd: Date?,
        gateStart: Date?, gateEnd: Date?, quality: BedtimeQuality, validity: Validity,
        tzOffsetMinutes: Int
    ) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.gateStart = gateStart
        self.gateEnd = gateEnd
        self.quality = quality
        self.validity = validity
        self.tzOffsetMinutes = tzOffsetMinutes
    }

    /// The wake-day key from `periodEnd`, localised with the supplied
    /// (alertness-derived) offset — not circadian's own bogus field.
    public func wakeDayKey(offsetMinutes: Int) -> String {
        SleepWiseDayKey.string(from: periodEnd, offsetMinutes: offsetMinutes)
    }
}
