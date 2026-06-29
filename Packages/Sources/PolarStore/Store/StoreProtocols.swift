import Foundation
import PolarProtocol

/// Persistence contract: one idempotent upsert per domain. Implemented by
/// `PolarDatabase`; the Epic 5 sync engine depends on this protocol, not the
/// concrete records. Empty input is a no-op success (Safeguard 7).
public protocol StoreWriting {
    /// Minute upserts key each row on `(date, minute_ts)` where `date` is derived
    /// from the minute's *own UTC day* (see `PolarDayKey`). Callers pass minutes
    /// directly — there is deliberately no batch `date` to get wrong, so a window
    /// that crosses midnight dedups correctly however the API grouped it.
    func upsertHeartRateMinutes(_ minutes: [HeartRateMinute]) throws
    func upsertActivityMinutes(_ minutes: [StepMinute]) throws
    func upsertActivity(day: ActivityDay, zones: [ActivityZoneSample]) throws
    func upsertSleep(_ nights: [SleepNight]) throws
    func upsertRecharge(_ recharges: [NightlyRecharge]) throws
    func upsertCardioLoad(_ loads: [CardioLoad]) throws
    func upsertTrainingSessions(_ sessions: [TrainingSession]) throws
    func upsertSports(_ sports: [Sport]) throws
    func upsertDevice(_ device: Device) throws
    func recordSync(domain: String, window: String) throws
}

/// Read contract: display-ready queries over date windows / ids, resolved purely
/// from SQLite (zero network — Safeguard 3). Implemented by `PolarDatabase`; the
/// Epic 6 dashboard depends on this protocol. Absent data returns empty/`nil`.
public protocol StoreReading {
    func heartRateMinutes(in interval: DateInterval) throws -> [HeartRateMinute]
    func activityDay(date: String) throws -> ActivityDayView?
    func sleepNight(date: String) throws -> SleepNightView?
    func recharge(date: String) throws -> RechargeView?
    func cardioLoad(in range: ClosedRange<String>) throws -> [CardioLoadView]
    func trainingSessions(in interval: DateInterval) throws -> [TrainingSessionView]
    func sportName(id: Int) throws -> String?
    func device() throws -> DeviceView?
    func lastSync(domain: String) throws -> Date?
}
