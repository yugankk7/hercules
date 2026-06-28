import Foundation

/// One night from `GET /v3/users/nightly-recharge` (`recharges[]`). Verified
/// against a live capture (2026-06-28): the status fields are **integer codes**,
/// and `hrv_samples` / `breathing_samples` are **objects** keyed by clock time
/// (`"HH:MM"` → value), kept intact at this layer.
public struct NightlyRecharge: Decodable, Sendable, Equatable {
    public let date: String
    /// Signed ANS-charge deviation (e.g. `-1.5`) — a Double, not an integer.
    public let ansCharge: Double?
    public let ansChargeStatus: Int?
    public let nightlyRechargeStatus: Int?
    public let heartRateAvg: Double?
    public let heartRateVariabilityAvg: Double?
    public let breathingRateAvg: Double?
    public let beatToBeatAvg: Double?
    /// `"HH:MM"` → HRV sample.
    public let hrvSamples: [String: Double]
    /// `"HH:MM"` → breathing-rate sample.
    public let breathingSamples: [String: Double]

    enum CodingKeys: String, CodingKey {
        case date
        case ansCharge = "ans_charge"
        case ansChargeStatus = "ans_charge_status"
        case nightlyRechargeStatus = "nightly_recharge_status"
        case heartRateAvg = "heart_rate_avg"
        case heartRateVariabilityAvg = "heart_rate_variability_avg"
        case breathingRateAvg = "breathing_rate_avg"
        case beatToBeatAvg = "beat_to_beat_avg"
        case hrvSamples = "hrv_samples"
        case breathingSamples = "breathing_samples"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        ansCharge = try c.decodeIfPresent(Double.self, forKey: .ansCharge)
        ansChargeStatus = try c.decodeIfPresent(Int.self, forKey: .ansChargeStatus)
        nightlyRechargeStatus = try c.decodeIfPresent(Int.self, forKey: .nightlyRechargeStatus)
        heartRateAvg = try c.decodeIfPresent(Double.self, forKey: .heartRateAvg)
        heartRateVariabilityAvg = try c.decodeIfPresent(Double.self, forKey: .heartRateVariabilityAvg)
        breathingRateAvg = try c.decodeIfPresent(Double.self, forKey: .breathingRateAvg)
        beatToBeatAvg = try c.decodeIfPresent(Double.self, forKey: .beatToBeatAvg)
        hrvSamples = try c.decodeIfPresent([String: Double].self, forKey: .hrvSamples) ?? [:]
        breathingSamples = try c.decodeIfPresent([String: Double].self, forKey: .breathingSamples) ?? [:]
    }
}
