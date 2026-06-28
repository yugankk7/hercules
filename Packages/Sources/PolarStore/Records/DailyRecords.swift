import Foundation
import GRDB
import PolarProtocol

/// `activity_day` — v3 computed daily totals + per-minute zone label series.
/// See `API_RESPONSE_SHAPES.md` §6. `date` is derived from `start_time` upstream.
struct ActivityDayRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "activity_day"

    let date: String
    let startTime: Date?
    let endTime: Date?
    let steps: Int
    let calories: Int
    let activeCalories: Int
    let activeDur: Double
    let inactiveDur: Double
    let dailyActivity: Int
    let distance: Double
    let inactivityAlerts: Int
    let zonesJson: String

    enum CodingKeys: String, CodingKey {
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case steps, calories
        case activeCalories = "active_calories"
        case activeDur = "active_dur"
        case inactiveDur = "inactive_dur"
        case dailyActivity = "daily_activity"
        case distance
        case inactivityAlerts = "inactivity_alerts"
        case zonesJson = "zones_json"
    }

    init(day: ActivityDay, zones: [ActivityZoneSample]) throws {
        date = day.date
        startTime = day.startTime
        endTime = day.endTime
        steps = day.steps
        calories = day.calories
        activeCalories = day.activeCalories
        activeDur = day.activeDuration
        inactiveDur = day.inactiveDuration
        dailyActivity = day.dailyActivity
        distance = day.distanceFromSteps
        inactivityAlerts = day.inactivityAlertCount
        let entries = zones.map {
            ZoneEntryDTO(minuteTs: Int($0.minute.timeIntervalSince1970), label: zoneLabel($0.zone))
        }
        zonesJson = try StoreJSON.encode(entries)
    }

    func toView() throws -> ActivityDayView {
        let entries = try StoreJSON.decode([ZoneEntryDTO].self, from: zonesJson)
        let zones = entries.map {
            ActivityZoneSample(
                minute: Date(timeIntervalSince1970: Double($0.minuteTs)),
                zone: ActivityZoneKind(raw: $0.label)
            )
        }
        return ActivityDayView(
            date: date, startTime: startTime, endTime: endTime, steps: steps,
            calories: calories, activeCalories: activeCalories,
            activeDuration: activeDur, inactiveDuration: inactiveDur,
            dailyActivity: dailyActivity, distance: distance,
            inactivityAlerts: inactivityAlerts, zones: zones
        )
    }
}

/// `sleep_night` — score + flat stage totals + `"HH:MM"`-keyed hypnogram / HR maps
/// stored as JSON. See `API_RESPONSE_SHAPES.md` §1.
struct SleepNightRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "sleep_night"

    let date: String
    let score: Int?
    let stagesJson: String
    let hypnogramJson: String
    let hrSamplesJson: String
    let continuity: Double?
    let continuityClass: Int?
    let charge: Int?
    let cycles: Int?
    let startTime: Date?
    let endTime: Date?

    enum CodingKeys: String, CodingKey {
        case date, score
        case stagesJson = "stages_json"
        case hypnogramJson = "hypnogram_json"
        case hrSamplesJson = "hr_samples_json"
        case continuity
        case continuityClass = "continuity_class"
        case charge, cycles
        case startTime = "start_time"
        case endTime = "end_time"
    }

    init(night: SleepNight) throws {
        date = night.date
        score = night.sleepScore
        let stages = SleepStagesDTO(
            light: night.lightSleep, deep: night.deepSleep,
            rem: night.remSleep, interruption: night.totalInterruptionDuration
        )
        stagesJson = try StoreJSON.encode(stages)
        hypnogramJson = try StoreJSON.encode(night.hypnogram)
        hrSamplesJson = try StoreJSON.encode(night.heartRateSamples)
        continuity = night.continuity
        continuityClass = night.continuityClass
        charge = night.sleepCharge
        cycles = night.sleepCycles
        startTime = night.sleepStartTime
        endTime = night.sleepEndTime
    }

    func toView() throws -> SleepNightView {
        SleepNightView(
            date: date,
            score: score,
            stages: try StoreJSON.decode(SleepStagesDTO.self, from: stagesJson),
            hypnogram: try StoreJSON.decode([String: Int].self, from: hypnogramJson),
            hrSamples: try StoreJSON.decode([String: Int].self, from: hrSamplesJson),
            continuity: continuity,
            continuityClass: continuityClass,
            charge: charge,
            cycles: cycles,
            startTime: startTime,
            endTime: endTime
        )
    }
}

/// `recharge` — signed `ans_charge` (REAL) + `"HH:MM"`-keyed HRV / breathing maps
/// stored as JSON. See `API_RESPONSE_SHAPES.md` §3.
struct RechargeRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "recharge"

    let date: String
    let ansCharge: Double?
    let ansChargeStatus: Int?
    let nightlyRechargeStatus: Int?
    let hrAvg: Double?
    let hrvAvg: Double?
    let breathingAvg: Double?
    let beatToBeatAvg: Double?
    let hrvJson: String
    let breathingJson: String

    enum CodingKeys: String, CodingKey {
        case date
        case ansCharge = "ans_charge"
        case ansChargeStatus = "ans_charge_status"
        case nightlyRechargeStatus = "nightly_recharge_status"
        case hrAvg = "hr_avg"
        case hrvAvg = "hrv_avg"
        case breathingAvg = "breathing_avg"
        case beatToBeatAvg = "beat_to_beat_avg"
        case hrvJson = "hrv_json"
        case breathingJson = "breathing_json"
    }

    init(recharge: NightlyRecharge) throws {
        date = recharge.date
        ansCharge = recharge.ansCharge
        ansChargeStatus = recharge.ansChargeStatus
        nightlyRechargeStatus = recharge.nightlyRechargeStatus
        hrAvg = recharge.heartRateAvg
        hrvAvg = recharge.heartRateVariabilityAvg
        breathingAvg = recharge.breathingRateAvg
        beatToBeatAvg = recharge.beatToBeatAvg
        hrvJson = try StoreJSON.encode(recharge.hrvSamples)
        breathingJson = try StoreJSON.encode(recharge.breathingSamples)
    }

    func toView() throws -> RechargeView {
        RechargeView(
            date: date,
            ansCharge: ansCharge,
            ansChargeStatus: ansChargeStatus,
            nightlyRechargeStatus: nightlyRechargeStatus,
            hrAvg: hrAvg,
            hrvAvg: hrvAvg,
            breathingAvg: breathingAvg,
            beatToBeatAvg: beatToBeatAvg,
            hrvSamples: try StoreJSON.decode([String: Double].self, from: hrvJson),
            breathingSamples: try StoreJSON.decode([String: Double].self, from: breathingJson)
        )
    }
}

/// `cardio_load` — strain/tolerance/ratio + status label + level breakdown JSON.
/// See `API_RESPONSE_SHAPES.md` §4.
struct CardioLoadRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "cardio_load"

    let date: String
    let strain: Double
    let tolerance: Double
    let ratio: Double
    let cardioLoad: Double
    let status: String
    let levelJson: String?

    enum CodingKeys: String, CodingKey {
        case date, strain, tolerance, ratio
        case cardioLoad = "cardio_load"
        case status
        case levelJson = "level_json"
    }

    init(load: CardioLoad) throws {
        date = load.date
        strain = load.strain
        tolerance = load.tolerance
        ratio = load.ratio
        cardioLoad = load.cardioLoad
        status = cardioStatusString(load.status)
        if let level = load.level {
            levelJson = try StoreJSON.encode(CardioLevelDTO(level))
        } else {
            levelJson = nil
        }
    }

    func toView() throws -> CardioLoadView {
        let level = try levelJson.map { try StoreJSON.decode(CardioLoadLevel.self, from: $0) }
        return CardioLoadView(
            date: date, strain: strain, tolerance: tolerance, ratio: ratio,
            cardioLoad: cardioLoad, status: cardioStatus(fromRaw: status), level: level
        )
    }
}
