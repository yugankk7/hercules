import Foundation
import GRDB
import PolarProtocol

/// Display-ready reads (HERC-042). All queries run in `read {}` (zero network),
/// range over the indexed primary key, and rehydrate `*_json` columns into
/// `*View` read-models. Absent data returns empty/`nil`, never an error.
extension PolarDatabase: StoreReading {

    public func heartRateMinutes(in interval: DateInterval) throws -> [HeartRateMinute] {
        let lower = Int(interval.start.timeIntervalSince1970)
        let upper = Int(interval.end.timeIntervalSince1970)
        return try dbWriter.read { db in
            try HRMinuteRecord
                .filter(Column("minute_ts") >= lower && Column("minute_ts") <= upper)
                .order(Column("minute_ts"))
                .fetchAll(db)
                .map { $0.toMinute() }
        }
    }

    public func activityDay(date: String) throws -> ActivityDayView? {
        try dbWriter.read { db in
            guard let record = try ActivityDayRecord.fetchOne(db, key: date) else { return nil }
            return try record.toView()
        }
    }

    public func sleepNight(date: String) throws -> SleepNightView? {
        try dbWriter.read { db in
            guard let record = try SleepNightRecord.fetchOne(db, key: date) else { return nil }
            return try record.toView()
        }
    }

    public func recharge(date: String) throws -> RechargeView? {
        try dbWriter.read { db in
            guard let record = try RechargeRecord.fetchOne(db, key: date) else { return nil }
            return try record.toView()
        }
    }

    public func cardioLoad(in range: ClosedRange<String>) throws -> [CardioLoadView] {
        try dbWriter.read { db in
            try CardioLoadRecord
                .filter(Column("date") >= range.lowerBound && Column("date") <= range.upperBound)
                .order(Column("date"))
                .fetchAll(db)
                .map { try $0.toView() }
        }
    }

    public func trainingSessions(in interval: DateInterval) throws -> [TrainingSessionView] {
        try dbWriter.read { db in
            // Resolve sport names once (read-time lookup, not a join constraint).
            let sportNames = try Dictionary(
                SportRefRecord.fetchAll(db).map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
            let records = try TrainingSessionRecord
                .filter(Column("start") >= interval.start && Column("start") <= interval.end)
                .order(Column("start"))
                .fetchAll(db)
            return try records.map { try $0.toView(sportName: sportNames[$0.sportId]) }
        }
    }

    public func sportName(id: Int) throws -> String? {
        try dbWriter.read { db in
            try SportRefRecord.fetchOne(db, key: id)?.name
        }
    }

    public func device() throws -> DeviceView? {
        try dbWriter.read { db in
            guard let record = try DeviceRecord.fetchOne(db) else { return nil }
            return try record.toView()
        }
    }

    public func lastSync(domain: String) throws -> Date? {
        try dbWriter.read { db in
            try SyncStateRecord.fetchOne(db, key: domain)?.lastSyncedAt
        }
    }
}
