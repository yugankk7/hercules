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

        try db.upsertHeartRateMinutes(minutes)
        let afterFirst = try db.heartRateMinutes(in: interval)

        // Re-sync the same window: row count and contents must not change.
        try db.upsertHeartRateMinutes(minutes)
        let afterSecond = try db.heartRateMinutes(in: interval)

        XCTAssertEqual(afterFirst.count, 3)
        XCTAssertEqual(afterFirst, afterSecond)
        XCTAssertEqual(afterSecond, minutes)
    }

    // MARK: B1 — minute `date` is derived from the minute's own UTC day

    /// A window straddling UTC midnight must dedup on re-sync however the samples
    /// are grouped. Because `date` is derived per-minute (not from a batch label),
    /// the boundary minutes land under their correct UTC days and re-syncing the
    /// overlapping window yields identical row counts. See `PolarDayKey` / B1.
    func testMinuteDateDerivedFromUTCDayDedupsAcrossMidnight() throws {
        let db = try PolarDatabase(inMemory: true)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let midnight = utc.date(from: DateComponents(year: 2026, month: 6, day: 20))!

        // Three minutes straddling midnight: 23:59 (day 19), 00:00, 00:01 (day 20).
        let minutes = [
            HeartRateMinute(minute: midnight.addingTimeInterval(-60), min: 50, avg: 60, max: 70),
            HeartRateMinute(minute: midnight, min: 51, avg: 61, max: 71),
            HeartRateMinute(minute: midnight.addingTimeInterval(60), min: 52, avg: 62, max: 72),
        ]
        let interval = DateInterval(start: midnight.addingTimeInterval(-120),
                                    end: midnight.addingTimeInterval(120))

        try db.upsertHeartRateMinutes(minutes)
        let afterFirst = try db.heartRateMinutes(in: interval)
        // Re-sync the same straddling window — must not create midnight twins.
        try db.upsertHeartRateMinutes(minutes)
        let afterSecond = try db.heartRateMinutes(in: interval)

        XCTAssertEqual(afterFirst.count, 3)
        XCTAssertEqual(afterFirst, afterSecond)

        // The boundary samples are partitioned by their own UTC day, not one batch label.
        let days = try db.dbWriter.read { db in
            try String.fetchAll(db, sql: "SELECT date FROM hr_minute ORDER BY minute_ts")
        }
        XCTAssertEqual(days, ["2026-06-19", "2026-06-20", "2026-06-20"])
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
        XCTAssertNoThrow(try db.upsertHeartRateMinutes([]))

        let interval = DateInterval(start: .distantPast, end: .distantFuture)
        XCTAssertTrue(try db.heartRateMinutes(in: interval).isEmpty)
        XCTAssertNil(try db.sleepNight(date: "2026-06-20"))
    }

    // MARK: HERC-042 — latest activity day picks the most recent by date

    func testLatestActivityDayReturnsMostRecent() throws {
        let db = try PolarDatabase(inMemory: true)
        try db.upsertActivity(day: makeActivityDay(start: "2026-06-27T00:00:00", steps: 5000), zones: [])
        try db.upsertActivity(day: makeActivityDay(start: "2026-06-29T00:00:00", steps: 8432), zones: [])
        try db.upsertActivity(day: makeActivityDay(start: "2026-06-28T00:00:00", steps: 6000), zones: [])

        let latest = try XCTUnwrap(try db.latestActivityDay())
        XCTAssertEqual(latest.date, "2026-06-29")
        XCTAssertEqual(latest.steps, 8432)
    }

    // MARK: HERC-061 — store-backed dashboard provider populates the Activity card

    func testStoreDashboardProviderPopulatesActivityCard() async throws {
        let db = try PolarDatabase(inMemory: true)
        try db.upsertActivity(
            day: makeActivityDay(
                start: "2026-06-29T00:00:00", steps: 8432,
                calories: 2450, activeDuration: "PT1H23M", distance: 6100
            ),
            zones: []
        )
        try db.recordSync(domain: SyncDomain.activity.rawValue, window: "2026-06-29")

        let snapshot = await StoreDashboardProvider(store: db).snapshot()

        // All 8 cards present, in CardKind order; only Daily Activity is populated.
        XCTAssertEqual(snapshot.cards.map(\.kind), CardKind.allCases)
        let activity = try XCTUnwrap(snapshot.cards.first { $0.kind == .dailyActivity })
        XCTAssertEqual(activity.state, .populated)
        XCTAssertEqual(activity.headline, "8,432 STEPS")
        XCTAssertEqual(activity.detail, "2,450 KCAL · 6.1 KM · 1H 23M ACTIVE")
        for other in snapshot.cards where other.kind != .dailyActivity {
            XCTAssertEqual(other.state, .empty, "\(other.kind) should stay empty this slice")
        }
        if case .syncedAt = snapshot.freshness {} else {
            XCTFail("freshness should reflect the recorded sync")
        }
    }

    // MARK: HERC-061 — empty store yields an empty card, never an error

    func testStoreDashboardProviderEmptyStore() async throws {
        let db = try PolarDatabase(inMemory: true)
        let snapshot = await StoreDashboardProvider(store: db).snapshot()

        XCTAssertEqual(snapshot.cards.map(\.kind), CardKind.allCases)
        XCTAssertTrue(snapshot.cards.allSatisfy { $0.state == .empty })
        XCTAssertEqual(snapshot.freshness, .neverSynced)
    }

    // MARK: HERC-061 — activity detail provider derives zones / band / HR

    func testStoreActivityDetailProviderBuildsDetail() async throws {
        let db = try PolarDatabase(inMemory: true)
        var utc = Calendar(identifier: .gregorian); utc.timeZone = .gmt
        let dayStart = utc.date(from: DateComponents(year: 2026, month: 6, day: 29))!
        func at(_ minute: Int) -> Date { dayStart.addingTimeInterval(Double(minute) * 60) }

        // Zones: 3 SLEEP (early), 5 SEDENTARY, 4 LIGHT, 2 MODERATE, 1 VIGOROUS.
        var zones: [ActivityZoneSample] = (0..<3).map { ActivityZoneSample(minute: at($0), zone: .sleep) }
        zones += (480..<485).map { ActivityZoneSample(minute: at($0), zone: .sedentary) }
        zones += (600..<604).map { ActivityZoneSample(minute: at($0), zone: .light) }
        zones += (1080..<1082).map { ActivityZoneSample(minute: at($0), zone: .moderate) }
        zones += [ActivityZoneSample(minute: at(1085), zone: .vigorous)]

        try db.upsertActivity(
            day: makeActivityDay(start: "2026-06-29T00:00:00", steps: 8432, calories: 2450,
                                 activeDuration: "PT1H23M", distance: 6100, dailyActivity: 90),
            zones: zones
        )
        try db.upsertHeartRateMinutes([
            HeartRateMinute(minute: at(480), min: 60, avg: 66, max: 72),
            HeartRateMinute(minute: at(1085), min: 140, avg: 150, max: 158),
        ])

        let provider = StoreActivityDetailProvider(store: db)
        let days = await provider.availableDays()
        XCTAssertEqual(days, ["2026-06-29"])
        let result = await provider.detail(for: "2026-06-29")
        let detail = try XCTUnwrap(result)

        XCTAssertEqual(detail.steps, 8432)
        XCTAssertEqual(detail.distanceKm, 6.1, accuracy: 0.001)
        XCTAssertEqual(detail.activeMinutes, 83)
        XCTAssertEqual(detail.dailyActivityPct, 90)
        // REST / SIT / LOW / MED / HIGH
        XCTAssertEqual(detail.zones.map(\.minutes), [0, 5, 4, 2, 1])
        XCTAssertEqual(detail.awakeMinutes, 12)              // SLEEP excluded
        XCTAssertEqual(detail.intensity.count, 144)
        XCTAssertEqual(detail.intensity[48], 1)            // minute 480 (08:00) → SIT (level 1)
        XCTAssertEqual(detail.intensity.max(), 4)           // VIGOROUS bucket
        XCTAssertEqual(detail.hr.count, 2)
        XCTAssertEqual(detail.hr.first?.bpm, 66)
        XCTAssertNotNil(detail.sleepBlock)
    }

    func testStoreActivityDetailProviderListsDaysNewestFirst() async throws {
        let db = try PolarDatabase(inMemory: true)
        try db.upsertActivity(day: makeActivityDay(start: "2026-06-27T00:00:00", steps: 5000), zones: [])
        try db.upsertActivity(day: makeActivityDay(start: "2026-06-29T00:00:00", steps: 8432), zones: [])
        try db.upsertActivity(day: makeActivityDay(start: "2026-06-28T00:00:00", steps: 6000), zones: [])

        let provider = StoreActivityDetailProvider(store: db)
        let days = await provider.availableDays()
        XCTAssertEqual(days, ["2026-06-29", "2026-06-28", "2026-06-27"])
        let older = await provider.detail(for: "2026-06-27")
        XCTAssertEqual(older?.steps, 5000)
    }

    func testStoreActivityDetailProviderEmptyStoreReturnsNil() async throws {
        let db = try PolarDatabase(inMemory: true)
        let provider = StoreActivityDetailProvider(store: db)
        let days = await provider.availableDays()
        let detail = await provider.detail(for: "2026-06-29")
        XCTAssertTrue(days.isEmpty)
        XCTAssertNil(detail)
    }

    /// Decode an `ActivityDay` from a minimal v3 payload (its only initializer is
    /// `Decodable`; `date` is derived from `start_time`).
    private func makeActivityDay(
        start: String, steps: Int, calories: Int = 0,
        activeDuration: String = "PT0S", distance: Double = 0, dailyActivity: Int = 0
    ) throws -> ActivityDay {
        let json = """
        {"start_time":"\(start)","steps":\(steps),"calories":\(calories),
         "active_duration":"\(activeDuration)","distance_from_steps":\(distance),
         "daily_activity":\(dailyActivity)}
        """
        return try JSONDecoder().decode(ActivityDay.self, from: Data(json.utf8))
    }
}
