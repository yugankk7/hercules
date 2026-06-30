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
            // Nightly recharge — GET /v3/users/nightly-recharge. Server-bounded (~28 d).
            SyncDomainDescriptor(domain: .recharge, priority: .p1, policy: .windowless) { _ in
                try store.upsertRecharge(try await clients.v3.fetchNightlyRecharge())
            },
            // Cardio load — GET /v3/users/cardio-load. Server-bounded.
            SyncDomainDescriptor(domain: .cardioLoad, priority: .p1, policy: .windowless) { _ in
                try store.upsertCardioLoad(try await clients.v3.fetchCardioLoad())
            },
            // Continuous HR — GET /v3/users/continuous-heart-rate. Cap 30 d (§7);
            // 40 d lookback pages into two sub-requests on first sync.
            SyncDomainDescriptor(
                domain: .continuousHR,
                priority: .p1,
                policy: .windowed(lastDays: 40, capDays: 30)
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
                let day = try await clients.v3.fetchDailyActivity(date: date)
                let samples = try await clients.v3.fetchActivitySamples(date: date)
                try store.upsertActivity(day: day, zones: samples.zones)
                try store.upsertActivityMinutes(samples.steps)
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
