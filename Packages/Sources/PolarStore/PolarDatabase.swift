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

    /// Schema migrations. Empty in EPIC 0 — tables arrive in HERC-040.
    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        // Re-create the schema from scratch when migrations change, during dev.
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        // migrator.registerMigration("v1") { db in ... }  // HERC-040
        return migrator
    }

    /// HERC-002 acceptance check: a throwaway DB opens, runs, and closes cleanly.
    /// Returns `true` if GRDB is wired up correctly end-to-end.
    @discardableResult
    public static func selfTest() -> Bool {
        do {
            let db = try PolarDatabase(inMemory: true)
            let ok = try db.dbWriter.read { db in
                try Int.fetchOne(db, sql: "SELECT 1") == 1
            }
            return ok
        } catch {
            return false
        }
    }
}
