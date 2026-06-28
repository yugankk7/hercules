import Foundation

/// One night from `GET /v3/users/sleep` (`nights[]`). Verified against a live
/// capture (2026-06-28): `hypnogram` and `heart_rate_samples` are **objects**
/// keyed by clock time (`"HH:MM"` → value), and the stage totals + continuity are
/// **flat** fields on the night (not nested). Durations are seconds.
public struct SleepNight: Decodable, Sendable, Equatable {
    public let date: String
    /// `"HH:MM"` → stage code (0/1/3/4 = wake/REM/light/deep).
    public let hypnogram: [String: Int]
    /// `"HH:MM"` → heart rate (5-min cadence).
    public let heartRateSamples: [String: Int]
    public let lightSleep: Int?
    public let deepSleep: Int?
    public let remSleep: Int?
    public let totalInterruptionDuration: Int?
    public let sleepScore: Int?
    public let sleepCharge: Int?
    public let sleepCycles: Int?
    public let continuity: Double?
    public let continuityClass: Int?
    public let sleepStartTime: Date?
    public let sleepEndTime: Date?

    enum CodingKeys: String, CodingKey {
        case date
        case hypnogram
        case heartRateSamples = "heart_rate_samples"
        case lightSleep = "light_sleep"
        case deepSleep = "deep_sleep"
        case remSleep = "rem_sleep"
        case totalInterruptionDuration = "total_interruption_duration"
        case sleepScore = "sleep_score"
        case sleepCharge = "sleep_charge"
        case sleepCycles = "sleep_cycles"
        case continuity
        case continuityClass = "continuity_class"
        case sleepStartTime = "sleep_start_time"
        case sleepEndTime = "sleep_end_time"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        hypnogram = try c.decodeIfPresent([String: Int].self, forKey: .hypnogram) ?? [:]
        heartRateSamples = try c.decodeIfPresent([String: Int].self, forKey: .heartRateSamples) ?? [:]
        lightSleep = try c.decodeIfPresent(Int.self, forKey: .lightSleep)
        deepSleep = try c.decodeIfPresent(Int.self, forKey: .deepSleep)
        remSleep = try c.decodeIfPresent(Int.self, forKey: .remSleep)
        totalInterruptionDuration = try c.decodeIfPresent(Int.self, forKey: .totalInterruptionDuration)
        sleepScore = try c.decodeIfPresent(Int.self, forKey: .sleepScore)
        sleepCharge = try c.decodeIfPresent(Int.self, forKey: .sleepCharge)
        sleepCycles = try c.decodeIfPresent(Int.self, forKey: .sleepCycles)
        continuity = try c.decodeIfPresent(Double.self, forKey: .continuity)
        continuityClass = try c.decodeIfPresent(Int.self, forKey: .continuityClass)
        sleepStartTime = try c.decodeIfPresent(Date.self, forKey: .sleepStartTime)
        sleepEndTime = try c.decodeIfPresent(Date.self, forKey: .sleepEndTime)
    }
}

/// A manifest entry from `GET /v3/users/sleep/available` (`available[]`) — a date
/// that has sleep data, with its window. Decode-only; sync (Epic 5) uses it to
/// skip empty nights.
public struct SleepAvailability: Decodable, Sendable, Equatable {
    public let date: String
    public let start: Date?
    public let end: Date?

    enum CodingKeys: String, CodingKey {
        case date
        case start = "start_time"
        case end = "end_time"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        start = try c.decodeIfPresent(Date.self, forKey: .start)
        end = try c.decodeIfPresent(Date.self, forKey: .end)
    }
}
