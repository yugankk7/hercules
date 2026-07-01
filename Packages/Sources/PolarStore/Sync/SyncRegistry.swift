import Foundation
import PolarProtocol

/// The **single place** every domain's window, priority, and cap are written as
/// literals — "change a fetch window in one line" (HERC-050). Each descriptor
/// binds a `SyncDomain` to its v3/v4 client call and its `StoreWriting` upsert;
/// the orchestrator stays generic. Caps are verified against `ARCHITECTURE.md` §7.
public enum SyncRegistry {

    /// Build the standard set of domain descriptors. `clients` supplies the
    /// authenticated fetch calls; `store` the idempotent upserts. Window planning
    /// (and its clock) lives entirely in the engine, so the registry needs none.
    public static func standard(
        clients: SyncDataClients,
        store: any StoreWriting
    ) -> [SyncDomainDescriptor] {
        [
            // Sleep — GET /v3/users/sleep. Server-bounded (~28 d).
            SyncDomainDescriptor(domain: .sleep, priority: .p1, policy: .windowless) { _ in
                try store.upsertSleep(try await clients.v3.fetchSleep())
            },
            // SleepWise — GET /v3/users/sleepwise/alertness/date +
            // /circadian-bedtime/date. Each returns the full ~28-night set in one
            // call (windowless, like .sleep — capture 2026-07-01), so the descriptor
            // fetches both arrays once and upserts the merged nights. A decode/store
            // failure surfaces as this domain's failure without blocking others.
            SyncDomainDescriptor(domain: .sleepwise, priority: .p1, policy: .windowless) { _ in
                let alertness = try await clients.v3.fetchAlertness()
                let circadian = try await clients.v3.fetchCircadianBedtime()
                try store.upsertSleepwise(alertness, circadian: circadian)
            },
            // Nightly recharge — GET /v3/users/nightly-recharge. Server-bounded (~28 d).
            SyncDomainDescriptor(domain: .recharge, priority: .p1, policy: .windowless) { _ in
                try store.upsertRecharge(try await clients.v3.fetchNightlyRecharge())
            },
            // Cardio load — GET /v3/users/cardio-load. Server-bounded.
            SyncDomainDescriptor(domain: .cardioLoad, priority: .p1, policy: .windowless) { _ in
                try store.upsertCardioLoad(try await clients.v3.fetchCardioLoad())
            },
            // Continuous HR — GET /v3/users/continuous-heart-rate. API max range is
            // **28 days** (to − from), verified live: a 29-day range 400s with
            // "Date range between from and to cannot be more than 28 days". The
            // 40 d lookback pages into two sub-requests on first sync.
            SyncDomainDescriptor(
                domain: .continuousHR,
                priority: .p1,
                policy: .windowed(lastDays: 40, capDays: 28)
            ) { window in
                guard let window else { return }
                try store.upsertHeartRateMinutes(
                    try await clients.v3.fetchContinuousHeartRate(window)
                )
            },
            // Daily activity — GET /v3/users/activities/{date} (+ samples). Per-day
            // loop (HERC-052): each day fetched → downsampled (client-side) → upserted
            // before the next, bounding memory. Cap 90 d (§7).
            SyncDomainDescriptor(
                domain: .activity,
                priority: .p1,
                policy: .perDay(lastDays: 40)
            ) { window in
                guard let window else { return }
                let date = window.from
                do {
                    // A day with no wear data has no record on the server. Skip it
                    // silently (nil totals, or a 404) so one empty day doesn't fail
                    // the whole domain and block its sync anchor — real errors
                    // (auth/network/5xx/malformed) still propagate.
                    guard let day = try await clients.v3.fetchDailyActivity(date: date) else { return }
                    let samples = try await clients.v3.fetchActivitySamples(date: date)
                    try store.upsertActivity(day: day, zones: samples.zones)
                    try store.upsertActivityMinutes(samples.steps)
                } catch AuthError.httpStatus(404) {
                    return
                }
            },
            // Training sessions — GET /training-sessions/list. Cap 90 d (§7).
            SyncDomainDescriptor(
                domain: .trainingSessions,
                priority: .p1,
                policy: .windowed(lastDays: 90, capDays: 90)
            ) { window in
                guard let window else { return }
                try store.upsertTrainingSessions(
                    try await clients.v4.fetchTrainingSessions(window)
                )
            },
            // Sports catalog — GET /sports/list. Reference data (no dates).
            SyncDomainDescriptor(domain: .sports, priority: .p2, policy: .windowless) { _ in
                try store.upsertSports(try await clients.v4.fetchSports())
            },
            // Devices — GET /user-devices. No dates; upsert each returned device.
            SyncDomainDescriptor(domain: .devices, priority: .p2, policy: .windowless) { _ in
                for device in try await clients.v4.fetchDevices() {
                    try store.upsertDevice(device)
                }
            },
        ]
    }
}
