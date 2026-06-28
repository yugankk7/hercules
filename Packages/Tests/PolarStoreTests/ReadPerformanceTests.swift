import XCTest
import PolarProtocol
@testable import PolarStore

/// HERC-042 / Safeguard 3 — proves a card read returns well under the 16 ms frame
/// budget on a realistically populated DB. Not a strict gate (CI timing is noisy);
/// it prints actual latencies so the read path can be eyeballed.
final class ReadPerformanceTests: XCTestCase {

    func testHeartRateDayWindowReadIsFast() throws {
        let db = try PolarDatabase(inMemory: true)

        // Populate ~30 days of per-minute HR: 30 * 1440 = 43,200 rows.
        let dayCount = 30
        let minutesPerDay = 1440
        let calendar = Calendar(identifier: .gregorian)
        var dayStart = Date(timeIntervalSince1970: 1_700_000_000)

        for day in 0..<dayCount {
            let dateKey = "2026-06-\(String(format: "%02d", day + 1))"
            var minutes: [HeartRateMinute] = []
            minutes.reserveCapacity(minutesPerDay)
            for m in 0..<minutesPerDay {
                let ts = dayStart.addingTimeInterval(Double(m) * 60)
                minutes.append(HeartRateMinute(minute: ts, min: 50, avg: 60, max: 70))
            }
            try db.upsertHeartRateMinutes(date: dateKey, minutes)
            dayStart = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        }

        // Read a single day's window (1,440 rows) out of 43,200. End just before
        // the next day's first minute so the window holds exactly one day.
        let windowStart = Date(timeIntervalSince1970: 1_700_000_000)
        let interval = DateInterval(start: windowStart, end: windowStart.addingTimeInterval(86_340))

        // Warm once, then time.
        _ = try db.heartRateMinutes(in: interval)

        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            let rows = try db.heartRateMinutes(in: interval)
            XCTAssertEqual(rows.count, minutesPerDay)
        }

        let ms = Double(elapsed.components.attoseconds) / 1_000_000_000_000_000 + Double(elapsed.components.seconds) * 1000
        print("[perf] hr_minute day-window read (1440 of 43200 rows): \(String(format: "%.3f", ms)) ms")
    }
}
