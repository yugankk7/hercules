import Foundation

/// One day from `GET /v3/users/cardio-load` — the response is a **top-level
/// array** (28 days), no envelope. Verified against a live capture (2026-06-28):
/// `strain` / `tolerance` / `cardio_load_ratio` are siblings of `cardio_load`,
/// and `cardio_load_level` carries the zone breakdown.
public struct CardioLoad: Decodable, Sendable, Equatable {
    public let date: String
    public let strain: Double
    public let tolerance: Double
    public let ratio: Double
    public let cardioLoad: Double
    public let status: CardioLoadStatus
    public let level: CardioLoadLevel?

    enum CodingKeys: String, CodingKey {
        case date
        case strain
        case tolerance
        case ratio = "cardio_load_ratio"
        case cardioLoad = "cardio_load"
        case status = "cardio_load_status"
        case level = "cardio_load_level"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        strain = try c.decodeIfPresent(Double.self, forKey: .strain) ?? 0
        tolerance = try c.decodeIfPresent(Double.self, forKey: .tolerance) ?? 0
        ratio = try c.decodeIfPresent(Double.self, forKey: .ratio) ?? 0
        cardioLoad = try c.decodeIfPresent(Double.self, forKey: .cardioLoad) ?? 0
        status = try c.decodeIfPresent(CardioLoadStatus.self, forKey: .status) ?? .unknown("")
        level = try c.decodeIfPresent(CardioLoadLevel.self, forKey: .level)
    }
}

/// The intensity-zone breakdown carried on each cardio-load day.
public struct CardioLoadLevel: Decodable, Sendable, Equatable {
    public let veryLow: Double?
    public let low: Double?
    public let medium: Double?
    public let high: Double?
    public let veryHigh: Double?

    enum CodingKeys: String, CodingKey {
        case veryLow = "very_low"
        case low
        case medium
        case high
        case veryHigh = "very_high"
    }
}

/// Cardio-load status. Live values seen: `MAINTAINING`, `PRODUCTIVE`. Tolerant:
/// unrecognized wire values degrade to `.unknown(raw)` (Norm 3).
public enum CardioLoadStatus: Sendable, Equatable, Decodable {
    case detraining
    case maintaining
    case productive
    case overreaching
    case unknown(String)

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw.uppercased() {
        case "DETRAINING": self = .detraining
        case "MAINTAINING": self = .maintaining
        case "PRODUCTIVE": self = .productive
        case "OVERREACHING": self = .overreaching
        default: self = .unknown(raw)
        }
    }
}
