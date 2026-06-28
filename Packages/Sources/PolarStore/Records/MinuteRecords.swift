import Foundation
import GRDB
import PolarProtocol

/// `hr_minute` — per-minute HR buckets (min/avg/max), PK `(date, minute_ts)`.
/// See `API_RESPONSE_SHAPES.md` §5. `minute_ts` is epoch-seconds (UTC-floored),
/// so window queries are integer-fast and collision-free across days.
struct HRMinuteRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "hr_minute"

    let date: String
    let minuteTs: Int
    let min: Int
    let avg: Int
    let max: Int

    enum CodingKeys: String, CodingKey {
        case date
        case minuteTs = "minute_ts"
        case min, avg, max
    }

    init(date: String, minute: HeartRateMinute) {
        self.date = date
        self.minuteTs = Int(minute.minute.timeIntervalSince1970)
        self.min = minute.min
        self.avg = minute.avg
        self.max = minute.max
    }

    func toMinute() -> HeartRateMinute {
        HeartRateMinute(
            minute: Date(timeIntervalSince1970: Double(minuteTs)),
            min: min, avg: avg, max: max
        )
    }
}

/// `activity_minute` — per-minute step totals, PK `(date, minute_ts)`.
/// See `API_RESPONSE_SHAPES.md` §7.
struct ActivityMinuteRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "activity_minute"

    let date: String
    let minuteTs: Int
    let steps: Int

    enum CodingKeys: String, CodingKey {
        case date
        case minuteTs = "minute_ts"
        case steps
    }

    init(date: String, minute: StepMinute) {
        self.date = date
        self.minuteTs = Int(minute.minute.timeIntervalSince1970)
        self.steps = minute.steps
    }
}
