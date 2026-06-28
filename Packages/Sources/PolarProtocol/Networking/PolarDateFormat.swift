import Foundation

/// The **single place** Polar date strings are produced. AccessLink uses two
/// incompatible date dialects and rejects the wrong one with an identical,
/// unhelpful error (`ARCHITECTURE.md` §4):
///
/// - **`dateOnly`** (`YYYY-MM-DD`) — every v3 endpoint, plus the `/activities/{date}`
///   path segment.
/// - **`naiveDateTime`** (`YYYY-MM-DDTHH:MM:SS`, **no zone / offset / fractional
///   seconds**) — used **only** by the v4 `training-sessions/list` endpoint. Any
///   zoned form (`…Z`, `…+00:00`, `…000Z`) is rejected on input.
///
/// Both use a fixed `en_US_POSIX` locale and a Gregorian calendar; the caller
/// supplies the `TimeZone` that defines the local-day boundary. Formatters are
/// built per call rather than cached in a `static` (a shared mutable
/// `DateFormatter` is neither `Sendable` nor thread-safe — Safeguard 7).
public enum PolarDateFormat {
    /// `YYYY-MM-DD`. All v3 ranged params and `/activities/{date}` path dates.
    public static func dateOnly(_ date: Date, timeZone: TimeZone = .current) -> String {
        formatter("yyyy-MM-dd", timeZone).string(from: date)
    }

    /// `YYYY-MM-DDTHH:MM:SS` — naive, no timezone suffix. **Only** for v4
    /// `training-sessions/list`.
    public static func naiveDateTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        formatter("yyyy-MM-dd'T'HH:mm:ss", timeZone).string(from: date)
    }

    private static func formatter(_ format: String, _ timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = timeZone
        f.dateFormat = format
        return f
    }
}
