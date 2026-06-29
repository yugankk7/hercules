import Foundation
import PolarProtocol

/// The **single rule** for the `date` partition of the minute tables
/// (`hr_minute`, `activity_minute`). Their primary key is `(date, minute_ts)`,
/// where `minute_ts` is the minute's UTC epoch-second. If two syncs were to
/// label the *same absolute minute* with *different* `date` strings — e.g. a
/// midnight-boundary sample grouped under day N by one response and day N+1 by
/// the next — the composite key would admit **two rows for one minute**, a
/// silent dedup break (see `PRE-EPIC-5-store-readiness.md` B1).
///
/// Deriving the `date` from the minute's own UTC day makes the partition a pure
/// function of `minute_ts`, so re-syncing an overlapping window converges to the
/// same rows no matter how the API grouped the response. HR and activity ingest
/// both go through here so they can never drift apart. Day-window reads filter on
/// `minute_ts` alone and never inspect `date`, so this is invisible to readers.
enum PolarDayKey {
    /// `YYYY-MM-DD` for the UTC calendar day containing `date`. Reuses
    /// `PolarDateFormat` (the one place Polar date strings are produced) pinned
    /// to UTC, matching the UTC-floored `minute_ts`.
    static func utcDay(of date: Date) -> String {
        PolarDateFormat.dateOnly(date, timeZone: .gmt)
    }
}
