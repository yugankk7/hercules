import Foundation
import PolarProtocol

// JSON-column payloads and stable enum<->string mappings.
//
// The `PolarProtocol` wire models are decode-only (no `Encodable`), so the store
// owns small Codable mirrors for the values it must *write*. Reads decode back
// into the wire type wherever that type is itself `Decodable` (e.g.
// `CardioLoadLevel`); otherwise into these DTOs.

// MARK: - JSON column payloads

/// `sleep_night.stages_json` — the flat stage totals (seconds) from a `SleepNight`.
public struct SleepStagesDTO: Codable, Sendable, Equatable {
    public let light: Int?
    public let deep: Int?
    public let rem: Int?
    public let interruption: Int?

    public init(light: Int?, deep: Int?, rem: Int?, interruption: Int?) {
        self.light = light
        self.deep = deep
        self.rem = rem
        self.interruption = interruption
    }
}

/// One per-minute intensity-zone label in `activity_day.zones_json`.
struct ZoneEntryDTO: Codable, Sendable, Equatable {
    let minuteTs: Int
    let label: String

    enum CodingKeys: String, CodingKey {
        case minuteTs = "minute_ts"
        case label
    }
}

/// `cardio_load.level_json` — encodes with the same keys `CardioLoadLevel` decodes,
/// so a write→read round-trip restores a `CardioLoadLevel` (Safeguard 9).
struct CardioLevelDTO: Encodable {
    let veryLow: Double?
    let low: Double?
    let medium: Double?
    let high: Double?
    let veryHigh: Double?

    enum CodingKeys: String, CodingKey {
        case veryLow = "very_low"
        case low
        case medium
        case high
        case veryHigh = "very_high"
    }

    init(_ level: CardioLoadLevel) {
        veryLow = level.veryLow
        low = level.low
        medium = level.medium
        high = level.high
        veryHigh = level.veryHigh
    }
}

/// `training_session.macros_json` — encodes with the same keys `Exercise` decodes.
struct ExerciseDTO: Encodable {
    let fatPercentage: Double?
    let carboPercentage: Double?
    let proteinPercentage: Double?
    let calories: Int?
    let durationMillis: Int?

    init(_ exercise: Exercise) {
        fatPercentage = exercise.fatPercentage
        carboPercentage = exercise.carboPercentage
        proteinPercentage = exercise.proteinPercentage
        calories = exercise.calories
        durationMillis = exercise.durationMillis
    }
}

/// `device.settings_json` — battery is intentionally absent (Safeguard 4).
struct DeviceSettingsDTO: Codable, Sendable, Equatable {
    let automaticTrainingDetection: Bool?
}

// MARK: - Stable enum <-> string mapping (status / trigger / zone columns)

/// Stable wire label for an `ActivityZoneKind` (stored in `zones_json`).
func zoneLabel(_ kind: ActivityZoneKind) -> String {
    switch kind {
    case .sedentary: return "SEDENTARY"
    case .sleep: return "SLEEP"
    case .light: return "LIGHT"
    case .moderate: return "MODERATE"
    case .vigorous: return "VIGOROUS"
    case .nonWear: return "NON_WEAR"
    case .unknown(let raw): return raw
    }
}

/// Stable wire label for a `CardioLoadStatus` (stored in `cardio_load.status`).
func cardioStatusString(_ status: CardioLoadStatus) -> String {
    switch status {
    case .detraining: return "DETRAINING"
    case .maintaining: return "MAINTAINING"
    case .productive: return "PRODUCTIVE"
    case .overreaching: return "OVERREACHING"
    case .unknown(let raw): return raw
    }
}

/// Reconstruct a `CardioLoadStatus` from its stored label (read path).
func cardioStatus(fromRaw raw: String) -> CardioLoadStatus {
    switch raw.uppercased() {
    case "DETRAINING": return .detraining
    case "MAINTAINING": return .maintaining
    case "PRODUCTIVE": return .productive
    case "OVERREACHING": return .overreaching
    default: return .unknown(raw)
    }
}

/// Stable wire label for a `StartTrigger` (stored in `training_session.trigger`).
func triggerString(_ trigger: StartTrigger) -> String {
    switch trigger {
    case .manual: return "MANUAL"
    case .automaticTrainingDetection: return "TRAINING_START_AUTOMATIC_TRAINING_DETECTION"
    case .unknown(let raw): return raw
    }
}
