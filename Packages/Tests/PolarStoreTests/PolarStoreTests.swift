import XCTest
import PolarProtocol
@testable import PolarStore

/// Epic 4 acceptance tests: schema creation + idempotency (HERC-040/041) and
/// write→read round-trips (HERC-042 / Safeguard 9). Fixtures are built from the
/// wire models' public initializers; `CardioLoad` (no date fields) is decoded
/// from JSON to exercise the date-keyed + status-enum + JSON-column path.
final class PolarStoreTests: XCTestCase {

    // MARK: HERC-040 — schema + idempotent migration

    func testFreshInstallCreatesAllTables() throws {
        XCTAssertTrue(PolarDatabase.selfTest())
    }

    func testMigratingSameFileTwiceIsIdempotent() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("herc040-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        // First open creates the schema; second open re-runs the (no-op) migration.
        _ = try PolarDatabase(path: url)
        let reopened = try PolarDatabase(path: url)

        try reopened.dbWriter.read { db in
            for table in PolarDatabase.expectedTables {
                XCTAssertTrue(try db.tableExists(table), "missing table \(table)")
            }
        }
    }

    // MARK: HERC-041 — idempotent upsert (composite key)

    func testHeartRateMinuteUpsertIsIdempotent() throws {
        let db = try PolarDatabase(inMemory: true)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let minutes = [
            HeartRateMinute(minute: base, min: 50, avg: 60, max: 70),
            HeartRateMinute(minute: base.addingTimeInterval(60), min: 55, avg: 62, max: 75),
            HeartRateMinute(minute: base.addingTimeInterval(120), min: 58, avg: 64, max: 80),
        ]
        let interval = DateInterval(start: base.addingTimeInterval(-60), end: base.addingTimeInterval(600))

        try db.upsertHeartRateMinutes(date: "2026-06-20", minutes)
        let afterFirst = try db.heartRateMinutes(in: interval)

        // Re-sync the same window: row count and contents must not change.
        try db.upsertHeartRateMinutes(date: "2026-06-20", minutes)
        let afterSecond = try db.heartRateMinutes(in: interval)

        XCTAssertEqual(afterFirst.count, 3)
        XCTAssertEqual(afterFirst, afterSecond)
        XCTAssertEqual(afterSecond, minutes)
    }

    // MARK: HERC-041 — idempotent upsert (int key) + read-time name lookup

    func testSportRefIdempotentAndNameLookup() throws {
        let db = try PolarDatabase(inMemory: true)
        let sports = [Sport(id: 1, name: "RUNNING"), Sport(id: 15, name: "CYCLING")]

        try db.upsertSports(sports)
        try db.upsertSports(sports)

        XCTAssertEqual(try db.sportName(id: 1), "RUNNING")
        XCTAssertEqual(try db.sportName(id: 15), "CYCLING")
        XCTAssertNil(try db.sportName(id: 999))
    }

    // MARK: HERC-042 / Safeguard 9 — device round-trip (JSON settings column)

    func testDeviceRoundTrip() throws {
        let db = try PolarDatabase(inMemory: true)
        let device = Device(
            uuid: "uuid-1", firmware: "5.0.55", color: "Black",
            productDescription: "Polar Loop", hardwareIdentifier: "hw-1",
            registered: nil, automaticTrainingDetection: true
        )

        try db.upsertDevice(device)
        let view = try XCTUnwrap(try db.device())

        XCTAssertEqual(view.uuid, "uuid-1")
        XCTAssertEqual(view.firmware, "5.0.55")
        XCTAssertEqual(view.color, "Black")
        XCTAssertEqual(view.automaticTrainingDetection, true)
    }

    // MARK: HERC-042 / Safeguard 9 — cardio load round-trip (status + level_json)

    func testCardioLoadRoundTrip() throws {
        let db = try PolarDatabase(inMemory: true)
        let json = """
        [{"date":"2026-06-20","strain":1.2,"tolerance":3.4,"cardio_load_ratio":0.5,
          "cardio_load":10.0,"cardio_load_status":"PRODUCTIVE",
          "cardio_load_level":{"very_low":1,"low":2,"medium":3,"high":4,"very_high":5}}]
        """
        let loads = try JSONDecoder().decode([CardioLoad].self, from: Data(json.utf8))

        try db.upsertCardioLoad(loads)
        try db.upsertCardioLoad(loads) // idempotent re-sync

        let views = try db.cardioLoad(in: "2026-06-01"..."2026-06-30")
        XCTAssertEqual(views.count, 1)
        let view = try XCTUnwrap(views.first)
        XCTAssertEqual(view.date, "2026-06-20")
        XCTAssertEqual(view.status, .productive)
        XCTAssertEqual(view.cardioLoad, 10.0)
        XCTAssertEqual(view.level?.veryLow, 1)
        XCTAssertEqual(view.level?.veryHigh, 5)
    }

    // MARK: Safeguard 7 — empty input is a no-op success; reads return empty

    func testEmptyInputIsNoOp() throws {
        let db = try PolarDatabase(inMemory: true)
        XCTAssertNoThrow(try db.upsertSleep([]))
        XCTAssertNoThrow(try db.upsertHeartRateMinutes(date: "2026-06-20", []))

        let interval = DateInterval(start: .distantPast, end: .distantFuture)
        XCTAssertTrue(try db.heartRateMinutes(in: interval).isEmpty)
        XCTAssertNil(try db.sleepNight(date: "2026-06-20"))
    }
}
