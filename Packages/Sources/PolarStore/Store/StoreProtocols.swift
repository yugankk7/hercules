import Foundation
import PolarProtocol

/// Persistence contract: one idempotent upsert per domain. Implemented by
/// `PolarDatabase`; the Epic 5 sync engine depends on this protocol, not the
/// concrete records. Empty input is a no-op success (Safeguard 7). `Sendable`
/// so the engine can hold it across the concurrency boundary.
public protocol StoreWriting: Sendable {
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
/// `Sendable` so the engine can read `lastSync` across the concurrency boundary.
public protocol StoreReading: Sendable {
    func heartRateMinutes(in interval: DateInterval) throws -> [HeartRateMinute]
    func activityDay(date: String) throws -> ActivityDayView?
    /// The most recent `activity_day` row by date, or `nil` when none exists. Backs
    /// the dashboard glance, which shows the latest synced day without the caller
    /// having to know which dates are present.
    func latestActivityDay() throws -> ActivityDayView?
    /// All `activity_day` dates (`YYYY-MM-DD`), most-recent first. Backs the detail
    /// screen's day-swipe.
    func activityDates() throws -> [String]
    func sleepNight(date: String) throws -> SleepNightView?
    func recharge(date: String) throws -> RechargeView?
    func cardioLoad(in range: ClosedRange<String>) throws -> [CardioLoadView]
    func trainingSessions(in interval: DateInterval) throws -> [TrainingSessionView]
    func sportName(id: Int) throws -> String?
    func device() throws -> DeviceView?
    func lastSync(domain: String) throws -> Date?
}

/// The store surface the sync engine needs: write (upserts + `recordSync`) and
/// read (`lastSync` for incremental windowing — HERC-054). A single refinement so
/// the engine can hold one `any SyncStore` instead of two references to the same
/// instance. `PolarDatabase` already implements both, so the conformance is empty
/// and behaviour-free (Safeguard 9 — additive only, no schema change).
public protocol SyncStore: StoreWriting, StoreReading {}

extension PolarDatabase: SyncStore {}

