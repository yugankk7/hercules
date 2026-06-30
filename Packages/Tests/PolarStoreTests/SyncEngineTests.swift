import XCTest
import PolarProtocol
@testable import PolarStore

/// Epic 5 acceptance tests: `WindowPlanner` math (HERC-053/054), engine
/// partial-failure isolation (HERC-051), the per-day activity loop (HERC-052),
/// and incremental windowing (HERC-054). The engine is exercised over an
/// in-memory `PolarDatabase` with an injected clock — no network.
final class SyncEngineTests: XCTestCase {

    /// Thread-safe collector for the windows an action receives.
    private actor WindowRecorder {
        private(set) var windows: [DateWindow?] = []
        func record(_ window: DateWindow?) { windows.append(window) }
        var count: Int { windows.count }
    }

    private let cal = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func inclusiveSpanDays(_ window: DateWindow) -> Int {
        (cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: window.from),
            to: cal.startOfDay(for: window.to)
        ).day ?? 0) + 1
    }

    // MARK: HERC-053/054 — WindowPlanner (Safeguard 4/10)

    func testRecentWindowSpansRequestedDays() {
        let window = WindowPlanner.recentWindow(days: 7, now: now, calendar: cal)
        XCTAssertEqual(inclusiveSpanDays(window), 7)
        XCTAssertEqual(window.to, now)
    }

    func testSplitPagesOverCapIntoGapFreeSubWindows() {
        let window = WindowPlanner.recentWindow(days: 40, now: now, calendar: cal)
        // continuous-HR's real API limit: (to − from) ≤ 28 days.
        let chunks = WindowPlanner.split(window, capDays: 28, calendar: cal)
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks.first?.from, window.from)   // covers the whole window
        XCTAssertEqual(chunks.last?.to, window.to)        // last clamped to `to`
        XCTAssertEqual(chunks[0].to, chunks[1].from)      // no gap at the boundary
        // Each sub-window's range must satisfy the API cap: capDays is the day
        // delta (to − from), so inclusive dates ≤ capDays + 1 (29). A 30th date
        // (29-day range) is the live 400.
        for chunk in chunks {
            XCTAssertLessThanOrEqual(inclusiveSpanDays(chunk), 29)
        }
    }

    func testSplitWithinCapReturnsSingleWindow() {
        let window = WindowPlanner.recentWindow(days: 10, now: now, calendar: cal)
        XCTAssertEqual(WindowPlanner.split(window, capDays: 30, calendar: cal).count, 1)
    }

    func testDailyWindowsEnumeratesEachDay() {
        let window = WindowPlanner.recentWindow(days: 5, now: now, calendar: cal)
        XCTAssertEqual(WindowPlanner.dailyWindows(window, calendar: cal).count, 5)
    }

    func testSyncWindowFirstSyncIsFullLookback() {
        let full = WindowPlanner.recentWindow(days: 40, now: now, calendar: cal)
        let window = WindowPlanner.syncWindow(
            lastSync: nil, lookbackDays: 40, overlapDays: 2, now: now, calendar: cal
        )
        XCTAssertEqual(window.from, full.from)
        XCTAssertEqual(window.to, full.to)
    }

    func testSyncWindowIncrementalIsSmallAndClamped() {
        let last = now.addingTimeInterval(-2 * 86_400) // synced ~2 days ago
        let window = WindowPlanner.syncWindow(
            lastSync: last, lookbackDays: 40, overlapDays: 2, now: now, calendar: cal
        )
        XCTAssertLessThanOrEqual(inclusiveSpanDays(window), 6) // elapsed + overlap, ≪ 40
        XCTAssertGreaterThan(
            window.from,
            WindowPlanner.recentWindow(days: 40, now: now, calendar: cal).from
        )
    }

    func testSyncWindowClampsFutureAnchorToValidWindow() {
        let future = now.addingTimeInterval(5 * 86_400) // skewed/corrupt anchor, 5 days ahead
        let window = WindowPlanner.syncWindow(
            lastSync: future, lookbackDays: 40, overlapDays: 2, now: now, calendar: cal
        )
        XCTAssertLessThanOrEqual(window.from, window.to)        // never inverted
        XCTAssertEqual(window.from, cal.startOfDay(for: now))   // clamped to today
        // ⇒ a non-empty per-day plan, so the engine can't false-success on zero work.
        XCTAssertEqual(WindowPlanner.dailyWindows(window, calendar: cal).count, 1)
    }

    // MARK: HERC-051 — partial-failure isolation (Safeguard 2)

    func testPartialFailureIsolatesDomainsAndRecordsOnlySuccess() async throws {
        let db = try PolarDatabase(inMemory: true)
        struct Boom: Error {}
        let descriptors = [
            SyncDomainDescriptor(domain: .sleep, priority: .p1, policy: .windowless) { _ in },
            SyncDomainDescriptor(domain: .sports, priority: .p2, policy: .windowless) { _ in throw Boom() },
        ]
        let engine = SyncEngine(descriptors: descriptors, store: db, now: { Date() })

        let report = try await engine.refresh()

        XCTAssertEqual(report.outcomes.count, 2)
        XCTAssertEqual(report.outcomes.first { $0.domain == .sleep }?.result, .success)
        if case .failure = report.outcomes.first(where: { $0.domain == .sports })?.result {} else {
            XCTFail("sports should report failure")
        }
        // recordSync runs only for the fully-successful domain (anchor advanced).
        XCTAssertNotNil(try db.lastSync(domain: SyncDomain.sleep.rawValue))
        XCTAssertNil(try db.lastSync(domain: SyncDomain.sports.rawValue))
        // Any success ⇒ freshness advances; refresh never throws on partial failure.
        if case .syncedAt = report.freshness {} else { XCTFail("expected syncedAt freshness") }
    }

    // MARK: HERC-052 — per-day loop (Safeguard 3)

    func testPerDayFeedsOneWindowPerDayAndContinuesPastBadDay() async throws {
        let db = try PolarDatabase(inMemory: true)
        let recorder = WindowRecorder()
        struct BadDay: Error {}
        let descriptors = [
            SyncDomainDescriptor(domain: .activity, priority: .p1, policy: .perDay(lastDays: 5)) { window in
                await recorder.record(window)
                if await recorder.count == 1 { throw BadDay() } // first day fails
            }
        ]
        let engine = SyncEngine(descriptors: descriptors, store: db, now: { Date() })

        let report = try await engine.refresh()

        // 5-day lookback ⇒ 5 per-day invocations, all attempted despite the bad day.
        let count = await recorder.count
        XCTAssertEqual(count, 5)
        // A failed day fails the domain and skips recordSync (anchor not advanced).
        if case .failure = report.outcomes.first?.result {} else { XCTFail("activity should fail") }
        XCTAssertNil(try db.lastSync(domain: SyncDomain.activity.rawValue))
    }

    // MARK: HERC-054 — incremental shrinks the window after a prior success (Safeguard 6)

    func testIncrementalShrinksWindowAfterPriorSync() async throws {
        let db = try PolarDatabase(inMemory: true)

        // First sync (never-synced ⇒ full 30-day lookback).
        let fullRecorder = WindowRecorder()
        let full = [
            SyncDomainDescriptor(domain: .activity, priority: .p1, policy: .perDay(lastDays: 30)) { window in
                await fullRecorder.record(window)
            }
        ]
        _ = try await SyncEngine(descriptors: full, store: db, now: { Date() }).refresh()
        let fullCount = await fullRecorder.count
        XCTAssertEqual(fullCount, 30) // backfill loops the whole lookback

        // The success above advanced the anchor to ~now; the next refresh is incremental.
        let incRecorder = WindowRecorder()
        let inc = [
            SyncDomainDescriptor(domain: .activity, priority: .p1, policy: .perDay(lastDays: 30)) { window in
                await incRecorder.record(window)
            }
        ]
        _ = try await SyncEngine(descriptors: inc, store: db, now: { Date() }, overlapDays: 2).refresh()
        let incCount = await incRecorder.count
        XCTAssertLessThan(incCount, fullCount)   // far cheaper than a full re-pull
        XCTAssertLessThanOrEqual(incCount, 4)    // overlap(2) + elapsed ≈ a few days
    }
}
