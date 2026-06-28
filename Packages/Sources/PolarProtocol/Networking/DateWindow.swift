import Foundation

/// A `from`/`to` date pair for ranged endpoints. It only *formats* the bounds
/// into the correct dialect — it does **not** clamp to the API's max range
/// (continuous-samples 30 d, nightly-recharge 28 d, …). Range-cap splitting is a
/// sync-engine concern (Epic 5), so an over-cap window will surface as a `400`
/// from the API, attributable to the caller.
public struct DateWindow: Sendable, Equatable {
    public let from: Date
    public let to: Date

    public init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }

    /// `from`/`to` as `YYYY-MM-DD` query items (all v3 ranged endpoints).
    public func dateOnlyParams(timeZone: TimeZone = .current) -> [URLQueryItem] {
        [
            URLQueryItem(name: "from", value: PolarDateFormat.dateOnly(from, timeZone: timeZone)),
            URLQueryItem(name: "to", value: PolarDateFormat.dateOnly(to, timeZone: timeZone)),
        ]
    }

    /// `from`/`to` as naive datetime query items (**only** `training-sessions/list`).
    public func naiveDateTimeParams(timeZone: TimeZone = .current) -> [URLQueryItem] {
        [
            URLQueryItem(name: "from", value: PolarDateFormat.naiveDateTime(from, timeZone: timeZone)),
            URLQueryItem(name: "to", value: PolarDateFormat.naiveDateTime(to, timeZone: timeZone)),
        ]
    }
}
