import Foundation

/// Computed daily totals from `GET /v3/users/activities/{date}` (and the ranged
/// `?from=&to=` variant, which returns a **top-level array**). Verified against a
/// live capture (2026-06-28): there is no `date` field — it is derived from
/// `start_time`. ISO-8601 durations are parsed to `TimeInterval`.
public struct ActivityDay: Decodable, Sendable, Equatable {
    public let date: String
    public let startTime: Date?
    public let endTime: Date?
    public let steps: Int
    public let calories: Int
    public let activeCalories: Int
    public let activeDuration: TimeInterval
    public let inactiveDuration: TimeInterval
    public let dailyActivity: Int
    public let inactivityAlertCount: Int
    public let distanceFromSteps: Double

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case steps
        case calories
        case activeCalories = "active_calories"
        case activeDuration = "active_duration"
        case inactiveDuration = "inactive_duration"
        case dailyActivity = "daily_activity"
        case inactivityAlertCount = "inactivity_alert_count"
        case distanceFromSteps = "distance_from_steps"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let startRaw = try c.decodeIfPresent(String.self, forKey: .startTime)
        date = startRaw.map { String($0.prefix(10)) } ?? ""
        startTime = startRaw.flatMap { PolarDateParser.shared.date(from: $0) }
        if let endRaw = try c.decodeIfPresent(String.self, forKey: .endTime) {
            endTime = PolarDateParser.shared.date(from: endRaw)
        } else {
            endTime = nil
        }
        steps = try c.decodeIfPresent(Int.self, forKey: .steps) ?? 0
        calories = try c.decodeIfPresent(Int.self, forKey: .calories) ?? 0
        activeCalories = try c.decodeIfPresent(Int.self, forKey: .activeCalories) ?? 0
        activeDuration = Self.duration(try c.decodeIfPresent(String.self, forKey: .activeDuration))
        inactiveDuration = Self.duration(try c.decodeIfPresent(String.self, forKey: .inactiveDuration))
        if let d = try? c.decodeIfPresent(Double.self, forKey: .dailyActivity) {
            dailyActivity = Int(d.rounded())
        } else {
            dailyActivity = 0
        }
        inactivityAlertCount = try c.decodeIfPresent(Int.self, forKey: .inactivityAlertCount) ?? 0
        distanceFromSteps = try c.decodeIfPresent(Double.self, forKey: .distanceFromSteps) ?? 0
    }

    private static func duration(_ raw: String?) -> TimeInterval {
        guard let raw else { return 0 }
        return ISO8601Duration.seconds(from: raw) ?? 0
    }
}

/// Per-minute step + intensity-zone detail from
/// `GET /v3/users/activities/samples/{date}`. Steps are returned **down-sampled**
/// to minute buckets; the zone time-series and inactivity stamps pass through.
public struct ActivitySamples: Sendable, Equatable {
    public let date: String
    public let steps: [StepMinute]
    public let zones: [ActivityZoneSample]
    public let inactivityStamps: [InactivityStamp]

    public init(date: String, steps: [StepMinute], zones: [ActivityZoneSample], inactivityStamps: [InactivityStamp]) {
        self.date = date
        self.steps = steps
        self.zones = zones
        self.inactivityStamps = inactivityStamps
    }
}

/// A per-minute step bucket — maps to the eventual `activity_minute` table.
public struct StepMinute: Sendable, Equatable {
    public let minute: Date
    public let steps: Int

    public init(minute: Date, steps: Int) {
        self.minute = minute
        self.steps = steps
    }
}

/// A raw step sample (one interval). Decode intermediate — bucketed to
/// `StepMinute` by `Downsampler`, never returned from a client.
public struct RawStepSample: Sendable, Equatable {
    public let minute: Date
    public let steps: Int

    public init(minute: Date, steps: Int) {
        self.minute = minute
        self.steps = steps
    }
}

/// A per-minute intensity-zone label (`activity_zones.samples[]`).
public struct ActivityZoneSample: Sendable, Equatable {
    public let minute: Date
    public let zone: ActivityZoneKind

    public init(minute: Date, zone: ActivityZoneKind) {
        self.minute = minute
        self.zone = zone
    }
}

/// Activity intensity classes seen live: `SEDENTARY`, `SLEEP`, `LIGHT`,
/// `MODERATE`, `VIGOROUS`, `NON_WEAR`. Tolerant fallback for anything else.
public enum ActivityZoneKind: Sendable, Equatable {
    case sedentary
    case sleep
    case light
    case moderate
    case vigorous
    case nonWear
    case unknown(String)

    public init(raw: String) {
        switch raw.uppercased() {
        case "SEDENTARY": self = .sedentary
        case "SLEEP": self = .sleep
        case "LIGHT": self = .light
        case "MODERATE": self = .moderate
        case "VIGOROUS": self = .vigorous
        case "NON_WEAR", "NONWEAR": self = .nonWear
        default: self = .unknown(raw)
        }
    }
}

/// An inactivity marker (`inactivity_stamps.samples[].stamp`).
public struct InactivityStamp: Sendable, Equatable {
    public let time: Date

    public init(time: Date) {
        self.time = time
    }
}
