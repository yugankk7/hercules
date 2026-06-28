import Foundation

/// One workout from `GET /v4/data/training-sessions/list` (`trainingSessions[]`).
/// Rich inline summary — no per-session drilldown call (the endpoint rejects
/// `features`). Verified against a live capture (2026-06-28): `identifier.id`,
/// and **`sport.id` + `recoveryTimeMillis` are strings**. `startTime`/`stopTime`
/// are naive datetimes. Maps to the eventual `training_session` table.
public struct TrainingSession: Decodable, Sendable, Equatable {
    public let id: String
    public let startTime: Date
    public let stopTime: Date
    public let sportID: Int
    public let calories: Int?
    public let hrAvg: Int?
    public let hrMax: Int?
    public let trainingBenefit: String?
    public let recoveryTimeMillis: Int?
    public let durationMillis: Int?
    public let distanceMeters: Double?
    public let deviceID: String?
    public let note: String?
    public let startTrigger: StartTrigger
    public let exercises: [Exercise]

    enum CodingKeys: String, CodingKey {
        case identifier, sport, startTime, stopTime, calories, hrAvg, hrMax
        case trainingBenefit, recoveryTimeMillis, durationMillis, distanceMeters
        case deviceId, note, startTrigger, exercises
    }

    private struct Ref: Decodable { let id: String }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Ref.self, forKey: .identifier))?.id ?? ""
        startTime = try c.decode(Date.self, forKey: .startTime)
        stopTime = try c.decode(Date.self, forKey: .stopTime)
        // `sport.id` is a *string* on the wire (e.g. "15").
        sportID = (try? c.decode(Ref.self, forKey: .sport)).flatMap { Int($0.id) } ?? -1
        calories = try c.decodeIfPresent(Int.self, forKey: .calories)
        hrAvg = try c.decodeIfPresent(Int.self, forKey: .hrAvg)
        hrMax = try c.decodeIfPresent(Int.self, forKey: .hrMax)
        trainingBenefit = try c.decodeIfPresent(String.self, forKey: .trainingBenefit)
        // `recoveryTimeMillis` is a *string* on the wire (e.g. "32060568").
        if let recoveryRaw = try c.decodeIfPresent(String.self, forKey: .recoveryTimeMillis) {
            recoveryTimeMillis = Int(recoveryRaw)
        } else {
            recoveryTimeMillis = nil
        }
        durationMillis = try c.decodeIfPresent(Int.self, forKey: .durationMillis)
        distanceMeters = try c.decodeIfPresent(Double.self, forKey: .distanceMeters)
        deviceID = try c.decodeIfPresent(String.self, forKey: .deviceId)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        startTrigger = try c.decodeIfPresent(StartTrigger.self, forKey: .startTrigger) ?? .unknown("")
        exercises = try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
    }
}

/// Inline macro split (+ optional totals) for an exercise within a session.
public struct Exercise: Decodable, Sendable, Equatable {
    public let fatPercentage: Double?
    public let carboPercentage: Double?
    public let proteinPercentage: Double?
    public let calories: Int?
    public let durationMillis: Int?

    enum CodingKeys: String, CodingKey {
        case fatPercentage, carboPercentage, proteinPercentage, calories, durationMillis
    }

    public init(fatPercentage: Double? = nil, carboPercentage: Double? = nil, proteinPercentage: Double? = nil, calories: Int? = nil, durationMillis: Int? = nil) {
        self.fatPercentage = fatPercentage
        self.carboPercentage = carboPercentage
        self.proteinPercentage = proteinPercentage
        self.calories = calories
        self.durationMillis = durationMillis
    }
}

/// How a session started. Live value: `TRAINING_START_AUTOMATIC_TRAINING_DETECTION`
/// (auto-detected) vs. a manual/empty trigger. Tolerant fallback (Norm 3).
public enum StartTrigger: Sendable, Equatable, Decodable {
    case manual
    case automaticTrainingDetection
    case unknown(String)

    /// `true` for sessions the band auto-detected (vs. user-started).
    public var isAutoDetected: Bool { self == .automaticTrainingDetection }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let upper = raw.uppercased()
        if upper.contains("AUTOMATIC_TRAINING_DETECTION") {
            self = .automaticTrainingDetection
        } else if upper.contains("MANUAL") {
            self = .manual
        } else {
            self = .unknown(raw)
        }
    }
}
