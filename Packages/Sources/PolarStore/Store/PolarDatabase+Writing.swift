import Foundation
import GRDB
import PolarProtocol

/// Transactional, idempotent writes (HERC-041). Each method maps wire→record and
/// upserts on the natural primary key inside a single `write {}` transaction, so
/// re-syncing an overlapping window converges to identical rows (Safeguard 2).
extension PolarDatabase: StoreWriting {

    public func upsertHeartRateMinutes(_ minutes: [HeartRateMinute]) throws {
        guard !minutes.isEmpty else { return }
        try dbWriter.write { db in
            for minute in minutes {
                try HRMinuteRecord(minute: minute).upsert(db)
            }
        }
    }

    public func upsertActivityMinutes(_ minutes: [StepMinute]) throws {
        guard !minutes.isEmpty else { return }
        try dbWriter.write { db in
            for minute in minutes {
                try ActivityMinuteRecord(minute: minute).upsert(db)
            }
        }
    }

    public func upsertActivity(day: ActivityDay, zones: [ActivityZoneSample]) throws {
        try dbWriter.write { db in
            try ActivityDayRecord(day: day, zones: zones).upsert(db)
        }
    }

    public func upsertSleep(_ nights: [SleepNight]) throws {
        guard !nights.isEmpty else { return }
        try dbWriter.write { db in
            for night in nights {
                try SleepNightRecord(night: night).upsert(db)
            }
        }
    }

    public func upsertSleepwise(_ alertness: [Alertness], circadian: [CircadianBedtime]) throws {
        guard !(alertness.isEmpty && circadian.isEmpty) else { return }
        // One authoritative offset per user (alertness); circadian's is unreliable.
        let fallbackOffset = alertness.first?.tzOffsetMinutes ?? 0

        // Zip the two arrays by wake-day key; a night present in only one array
        // still upserts its available fields (degrade per-field).
        var merged: [String: (alertness: Alertness?, circadian: CircadianBedtime?)] = [:]
        for entry in alertness {
            merged[entry.wakeDayKey(), default: (nil, nil)].alertness = entry
        }
        for entry in circadian {
            merged[entry.wakeDayKey(offsetMinutes: fallbackOffset), default: (nil, nil)].circadian = entry
        }

        try dbWriter.write { db in
            for (key, pair) in merged {
                try SleepwiseDayRecord(
                    date: key, alertness: pair.alertness, circadian: pair.circadian,
                    fallbackOffset: fallbackOffset
                ).upsert(db)
            }
        }
    }

    public func upsertRecharge(_ recharges: [NightlyRecharge]) throws {
        guard !recharges.isEmpty else { return }
        try dbWriter.write { db in
            for recharge in recharges {
                try RechargeRecord(recharge: recharge).upsert(db)
            }
        }
    }

    public func upsertCardioLoad(_ loads: [CardioLoad]) throws {
        guard !loads.isEmpty else { return }
        try dbWriter.write { db in
            for load in loads {
                try CardioLoadRecord(load: load).upsert(db)
            }
        }
    }

    public func upsertTrainingSessions(_ sessions: [TrainingSession]) throws {
        guard !sessions.isEmpty else { return }
        try dbWriter.write { db in
            for session in sessions {
                try TrainingSessionRecord(session: session).upsert(db)
            }
        }
    }

    public func upsertSports(_ sports: [Sport]) throws {
        guard !sports.isEmpty else { return }
        try dbWriter.write { db in
            for sport in sports {
                try SportRefRecord(sport: sport).upsert(db)
            }
        }
    }

    public func upsertDevice(_ device: Device) throws {
        try dbWriter.write { db in
            try DeviceRecord(device: device).upsert(db)
        }
    }

    public func recordSync(domain: String, window: String) throws {
        try dbWriter.write { db in
            try SyncStateRecord(domain: domain, lastSyncedAt: Date(), lastWindow: window).upsert(db)
        }
    }
}
