import Foundation
import GRDB
import PolarProtocol

/// `training_session` — v4 workout summaries with inline macros. `sport_id` and
/// `recovery_ms` are already normalized to Int by the wire model; `macros_json`
/// holds the `exercises[]` array. See `API_RESPONSE_SHAPES.md` §8.
struct TrainingSessionRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "training_session"

    let id: String
    let start: Date
    let stop: Date
    let sportId: Int
    let calories: Int?
    let hrAvg: Int?
    let hrMax: Int?
    let benefit: String?
    let recoveryMs: Int?
    let durationMs: Int?
    let distanceM: Double?
    let note: String?
    let trigger: String
    let macrosJson: String

    enum CodingKeys: String, CodingKey {
        case id, start, stop
        case sportId = "sport_id"
        case calories
        case hrAvg = "hr_avg"
        case hrMax = "hr_max"
        case benefit
        case recoveryMs = "recovery_ms"
        case durationMs = "duration_ms"
        case distanceM = "distance_m"
        case note, trigger
        case macrosJson = "macros_json"
    }

    init(session: TrainingSession) throws {
        id = session.id
        start = session.startTime
        stop = session.stopTime
        sportId = session.sportID
        calories = session.calories
        hrAvg = session.hrAvg
        hrMax = session.hrMax
        benefit = session.trainingBenefit
        recoveryMs = session.recoveryTimeMillis
        durationMs = session.durationMillis
        distanceM = session.distanceMeters
        note = session.note
        trigger = triggerString(session.startTrigger)
        macrosJson = try StoreJSON.encode(session.exercises.map(ExerciseDTO.init))
    }

    func toView(sportName: String?) throws -> TrainingSessionView {
        TrainingSessionView(
            id: id, start: start, stop: stop, sportId: sportId, sportName: sportName,
            calories: calories, hrAvg: hrAvg, hrMax: hrMax, benefit: benefit,
            recoveryMs: recoveryMs, durationMs: durationMs, distanceM: distanceM,
            note: note, trigger: trigger,
            macros: try StoreJSON.decode([Exercise].self, from: macrosJson)
        )
    }
}

/// `sport_ref` — cached id→name catalog. See `API_RESPONSE_SHAPES.md` §9.
struct SportRefRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "sport_ref"

    let id: Int
    let name: String

    init(sport: Sport) {
        id = sport.id
        name = sport.name
    }
}

/// `device` — flattened device facts; battery intentionally absent (BLE phase 2).
/// See `API_RESPONSE_SHAPES.md` §10.
struct DeviceRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "device"

    let uuid: String
    let firmware: String?
    let color: String?
    let productDescription: String?
    let hardwareId: String?
    let registered: Date?
    let settingsJson: String

    enum CodingKeys: String, CodingKey {
        case uuid, firmware, color
        case productDescription = "description"
        case hardwareId = "hardware_id"
        case registered
        case settingsJson = "settings_json"
    }

    init(device: Device) throws {
        uuid = device.uuid
        firmware = device.firmware
        color = device.color
        productDescription = device.productDescription
        hardwareId = device.hardwareIdentifier
        registered = device.registered
        settingsJson = try StoreJSON.encode(
            DeviceSettingsDTO(automaticTrainingDetection: device.automaticTrainingDetection)
        )
    }

    func toView() throws -> DeviceView {
        let settings = try StoreJSON.decode(DeviceSettingsDTO.self, from: settingsJson)
        return DeviceView(
            uuid: uuid, firmware: firmware, color: color,
            productDescription: productDescription, hardwareIdentifier: hardwareId,
            registered: registered, automaticTrainingDetection: settings.automaticTrainingDetection
        )
    }
}

/// `sync_state` — per-domain sync bookkeeping; written by the Epic 5 sync engine,
/// read by the dashboard freshness display. See `ARCHITECTURE.md` §9.
struct SyncStateRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "sync_state"

    let domain: String
    let lastSyncedAt: Date
    let lastWindow: String

    enum CodingKeys: String, CodingKey {
        case domain
        case lastSyncedAt = "last_synced_at"
        case lastWindow = "last_window"
    }
}
