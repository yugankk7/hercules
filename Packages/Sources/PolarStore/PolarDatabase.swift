import Foundation
import GRDB

/// The local, GRDB/SQLite-backed store. Phase-1 UI reads **only** from here;
/// no screen ever blocks on the network (see `ARCHITECTURE.md` §1, §9).
///
/// This is the EPIC-0 foundation: it opens a connection and runs an (empty)
/// migrator. Concrete tables and read APIs land in EPIC 4 (HERC-040+).
public final class PolarDatabase: Sendable {

    /// The GRDB database access point.
    public let dbWriter: any DatabaseWriter

    /// Open the store at `url` on disk (creating it if needed) and migrate.
    public init(path url: URL) throws {
        let pool = try DatabasePool(path: url.path)
        self.dbWriter = pool
        try Self.migrator.migrate(pool)
    }

    /// Open an in-memory store — used by `selfTest()` and unit tests.
    public init(inMemory: Bool) throws {
        let queue = try DatabaseQueue()
        self.dbWriter = queue
        try Self.migrator.migrate(queue)
    }

    /// Schema migrations (HERC-040). One `v1` migration creates the full phase-1
    /// schema. Columns/keys mirror `API_RESPONSE_SHAPES.md`; time-keyed maps and
    /// nested objects are `*_json` TEXT. GRDB tracks applied migrations, so a
    /// re-run is a no-op (Safeguard 1). `date` is the wire `"YYYY-MM-DD"`;
    /// `minute_ts` is epoch-seconds (Norm 7).
    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        // Re-create the schema from scratch when migrations change, during dev.
        // Guarded to DEBUG only — release builds never auto-wipe data (Safeguard 8).
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1") { db in
            // hr_minute — §5 (downsampled continuous HR)
            try db.create(table: "hr_minute") { t in
                t.column("date", .text).notNull()
                t.column("minute_ts", .integer).notNull()
                t.column("min", .integer)
                t.column("avg", .integer)
                t.column("max", .integer)
                t.primaryKey(["date", "minute_ts"])
            }

            // activity_minute — §7 (downsampled step samples)
            try db.create(table: "activity_minute") { t in
                t.column("date", .text).notNull()
                t.column("minute_ts", .integer).notNull()
                t.column("steps", .integer)
                t.primaryKey(["date", "minute_ts"])
            }

            // Time-range reads (HERC-042) filter on `minute_ts` alone, which the
            // composite PK (date-first) can't serve — index it explicitly so a
            // day-window read is an index range scan, not a full-table scan.
            try db.create(index: "idx_hr_minute_ts", on: "hr_minute", columns: ["minute_ts"])
            try db.create(index: "idx_activity_minute_ts", on: "activity_minute", columns: ["minute_ts"])

            // activity_day — §6 (computed totals + per-minute zone labels)
            try db.create(table: "activity_day") { t in
                t.primaryKey("date", .text)
                t.column("start_time", .datetime)
                t.column("end_time", .datetime)
                t.column("steps", .integer)
                t.column("calories", .integer)
                t.column("active_calories", .integer)
                t.column("active_dur", .double)
                t.column("inactive_dur", .double)
                t.column("daily_activity", .integer)
                t.column("distance", .double)
                t.column("inactivity_alerts", .integer)
                t.column("zones_json", .text)
            }

            // sleep_night — §1 (hypnogram/HR-sample maps as JSON)
            try db.create(table: "sleep_night") { t in
                t.primaryKey("date", .text)
                t.column("score", .integer)
                t.column("stages_json", .text)
                t.column("hypnogram_json", .text)
                t.column("hr_samples_json", .text)
                t.column("continuity", .double)
                t.column("continuity_class", .integer)
                t.column("charge", .integer)
                t.column("cycles", .integer)
                t.column("start_time", .datetime)
                t.column("end_time", .datetime)
            }

            // recharge — §3 (signed ans_charge; HRV/breathing maps as JSON)
            try db.create(table: "recharge") { t in
                t.primaryKey("date", .text)
                t.column("ans_charge", .double)
                t.column("ans_charge_status", .integer)
                t.column("nightly_recharge_status", .integer)
                t.column("hr_avg", .double)
                t.column("hrv_avg", .double)
                t.column("breathing_avg", .double)
                t.column("beat_to_beat_avg", .double)
                t.column("hrv_json", .text)
                t.column("breathing_json", .text)
            }

            // cardio_load — §4
            try db.create(table: "cardio_load") { t in
                t.primaryKey("date", .text)
                t.column("strain", .double)
                t.column("tolerance", .double)
                t.column("ratio", .double)
                t.column("cardio_load", .double)
                t.column("status", .text)
                t.column("level_json", .text)
            }

            // training_session — §8 (sport_id/recovery_ms normalized to INT)
            try db.create(table: "training_session") { t in
                t.primaryKey("id", .text)
                t.column("start", .datetime)
                t.column("stop", .datetime)
                t.column("sport_id", .integer)
                t.column("calories", .integer)
                t.column("hr_avg", .integer)
                t.column("hr_max", .integer)
                t.column("benefit", .text)
                t.column("recovery_ms", .integer)
                t.column("duration_ms", .integer)
                t.column("distance_m", .double)
                t.column("note", .text)
                t.column("trigger", .text)
                t.column("macros_json", .text)
            }

            // sport_ref — §9 (cached id→name catalog; no hard FK from sessions)
            try db.create(table: "sport_ref") { t in
                t.primaryKey("id", .integer)
                t.column("name", .text)
            }

            // device — §10 (battery intentionally absent)
            try db.create(table: "device") { t in
                t.primaryKey("uuid", .text)
                t.column("firmware", .text)
                t.column("color", .text)
                t.column("description", .text)
                t.column("hardware_id", .text)
                t.column("registered", .datetime)
                t.column("settings_json", .text)
            }

            // sync_state — per-domain sync bookkeeping (written by Epic 5)
            try db.create(table: "sync_state") { t in
                t.primaryKey("domain", .text)
                t.column("last_synced_at", .datetime)
                t.column("last_window", .text)
            }
        }

        // v2 (HERC-092) — SleepWise merged night. Additive: creates one new table
        // and touches no existing row (Safeguard 7). Shapes follow the live
        // capture (2026-07-01): grade is REAL, enum bands are TEXT tokens, hourly
        // buckets are JSON, gate/window are raw UTC datetimes localised at read
        // time, and a single alertness-derived offset is stored per night.
        migrator.registerMigration("v2") { db in
            try db.create(table: "sleepwise_day") { t in
                t.primaryKey("date", .text)          // wake-day key
                t.column("grade", .double)
                t.column("classification", .text)
                t.column("validity", .text)
                t.column("sleep_inertia", .text)
                t.column("hourly_json", .text)
                t.column("gate_start", .datetime)
                t.column("gate_end", .datetime)
                t.column("window_start", .datetime)
                t.column("window_end", .datetime)
                t.column("quality", .text)
                t.column("tz_offset_minutes", .integer)
            }
        }

        return migrator
    }

    /// The eleven tables created by migrations `v1` (ten) + `v2` (`sleepwise_day`).
    static let expectedTables = [
        "hr_minute", "activity_minute", "activity_day", "sleep_night",
        "recharge", "cardio_load", "training_session", "sport_ref",
        "device", "sync_state", "sleepwise_day",
    ]

    /// Acceptance check (HERC-002 + HERC-040): a throwaway DB opens, migrates, and
    /// contains all ten phase-1 tables. Returns `true` if GRDB is wired up
    /// end-to-end and the schema applied cleanly.
    @discardableResult
    public static func selfTest() -> Bool {
        do {
            let db = try PolarDatabase(inMemory: true)
            return try db.dbWriter.read { db in
                for table in expectedTables where try !db.tableExists(table) {
                    return false
                }
                return try Int.fetchOne(db, sql: "SELECT 1") == 1
            }
        } catch {
            return false
        }
    }
}
