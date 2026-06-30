import Foundation
import PolarProtocol

/// Pure window math for the registry/engine: builds, narrows, splits, and
/// enumerates `DateWindow`s. No I/O, no shared state — deterministic given
/// `lastSync` + `now` + `calendar`, so every fetch-window decision is unit-tested
/// in one place (HERC-053/054). All date arithmetic for fetch windows goes
/// through here (Norm 7).
public enum WindowPlanner {

    /// The full lookback window ending at `now`: `[startOfDay(now) − (days − 1), now]`,
    /// i.e. `days` calendar days inclusive. `days <= 0` clamps to a single day.
    public static func recentWindow(
        days: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> DateWindow {
        let safeDays = max(days, 1)
        let startToday = calendar.startOfDay(for: now)
        let from = calendar.date(byAdding: .day, value: -(safeDays - 1), to: startToday) ?? startToday
        return DateWindow(from: from, to: now)
    }

    /// Page an over-cap window into consecutive `≤ capDays` sub-windows. A window
    /// spanning `<= capDays` calendar days returns unchanged; otherwise it walks
    /// from `window.from` in `capDays` strides, the final chunk clamped to
    /// `window.to`. No gaps; touching/overlapping boundaries are acceptable
    /// (idempotent upserts dedup — Norm 5).
    public static func split(
        _ window: DateWindow,
        capDays: Int,
        calendar: Calendar = .current
    ) -> [DateWindow] {
        let cap = max(capDays, 1)
        let startDay = calendar.startOfDay(for: window.from)
        let endDay = calendar.startOfDay(for: window.to)
        let spanDays = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        guard spanDays > cap else { return [window] }

        var result: [DateWindow] = []
        var cursorFrom = window.from
        while cursorFrom < window.to {
            let nextStart = calendar.date(
                byAdding: .day,
                value: cap,
                to: calendar.startOfDay(for: cursorFrom)
            ) ?? window.to
            let cursorTo = min(nextStart, window.to)
            result.append(DateWindow(from: cursorFrom, to: cursorTo))
            cursorFrom = cursorTo
        }
        return result
    }

    /// One `DateWindow` per calendar day in `[from, to]`, each
    /// `[startOfDay(d), startOfDay(d) + 1 day)` — the per-day activity loop
    /// (HERC-052).
    public static func dailyWindows(
        _ window: DateWindow,
        calendar: Calendar = .current
    ) -> [DateWindow] {
        var result: [DateWindow] = []
        var day = calendar.startOfDay(for: window.from)
        let lastDay = calendar.startOfDay(for: window.to)
        while day <= lastDay {
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? lastDay
            result.append(DateWindow(from: day, to: next))
            if next <= day { break }
            day = next
        }
        return result
    }

    /// The effective fetch window for an incremental sync (HERC-054): the full
    /// `lookbackDays` backfill when a domain has never synced (`lastSync == nil`),
    /// otherwise `[startOfDay(lastSync) − overlapDays, now]` — only the days
    /// changed since the last *successful* sync. The lower bound is clamped into
    /// `[lookbackFrom, startOfDay(now)]`: never older than the configured lookback,
    /// and never *after* today — a future-dated or clock-skewed `lastSync` would
    /// otherwise produce `from > to` (an empty/inverted window the engine would
    /// treat as a no-op success). Worst case re-pulls today, which the idempotent
    /// store absorbs. `overlapDays <= 0` means "since lastSync, no buffer."
    public static func syncWindow(
        lastSync: Date?,
        lookbackDays: Int,
        overlapDays: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> DateWindow {
        guard let lastSync else {
            return recentWindow(days: lookbackDays, now: now, calendar: calendar)
        }
        let safeOverlap = max(overlapDays, 0)
        let lastDay = calendar.startOfDay(for: lastSync)
        let candidateFrom = calendar.date(byAdding: .day, value: -safeOverlap, to: lastDay) ?? lastDay
        let lookbackFrom = recentWindow(days: lookbackDays, now: now, calendar: calendar).from
        let from = min(max(candidateFrom, lookbackFrom), calendar.startOfDay(for: now))
        return DateWindow(from: from, to: now)
    }
}
