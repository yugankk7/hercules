import Foundation
import PolarProtocol

/// `StoreReading`-backed `BoostDetailProviding` (HERC-09x): assembles the Boost
/// From Sleep model from the merged `sleepwise_day` store, zero network. Selects
/// the render state from two distinct signals (Approach 5, verified live
/// 2026-07-01): a store-wide logged-nights count for `.calibrating`, and the
/// per-night `validity` for `.provisional`.
public struct StoreBoostDetailProvider: BoostDetailProviding {
    private let store: any StoreReading
    private let calibrationTarget: Int

    public init(store: any StoreReading, calibrationTarget: Int = 14) {
        self.store = store
        self.calibrationTarget = calibrationTarget
    }

    public func availableDays() async -> [String] {
        (try? store.sleepwiseDates()) ?? []
    }

    public func detail(for date: String) async -> BoostDetail {
        let nightsLogged = (try? store.sleepwiseNightsLogged()) ?? 0
        let title = Self.title(for: date)
        let dateLabel = Self.dateLabel(for: date)

        guard let row = (try? store.sleepwiseDay(date: date)) ?? nil else {
            return .noData(title: title, dateLabel: dateLabel,
                           nightsLogged: nightsLogged, calibrationTarget: calibrationTarget)
        }

        // Fresh-user gate: below the logged-nights threshold, no forecast is shown.
        if nightsLogged < calibrationTarget {
            return .calibrating(title: title, dateLabel: dateLabel,
                                nightsLogged: nightsLogged, calibrationTarget: calibrationTarget)
        }

        // Per-night confidence: an ESTIMATE night is interpolated → provisional.
        let state: BoostState = row.validity == .estimate ? .provisional : .forecast
        let bars = row.hourly.map { hour -> BoostBar in
            BoostBar(
                start: Self.localHour(hour.start, row.tzOffsetMinutes),
                end: Self.localHour(hour.end, row.tzOffsetMinutes),
                level: hour.level.rampLevel,
                isEstimate: hour.validity == .estimate
            )
        }.sorted { $0.start < $1.start }

        return BoostDetail(
            title: title, dateLabel: dateLabel, state: state,
            grade: row.grade, classification: row.classification,
            hourly: bars, window: row.window, gate: row.gate, inertia: row.inertia,
            nightsLogged: nightsLogged, calibrationTarget: calibrationTarget
        )
    }

    // MARK: - Axis / date helpers

    /// Fractional local hour [0,24) for a UTC date shifted by `offset` minutes.
    private static func localHour(_ date: Date, _ offset: Int) -> Double {
        let secs = date.timeIntervalSince1970 + Double(offset) * 60
        let inDay = secs.truncatingRemainder(dividingBy: 86_400)
        return (inDay < 0 ? inDay + 86_400 : inDay) / 3600
    }

    private static func utcMidnight(from date: String) -> Date? {
        formatter("yyyy-MM-dd", locale: "en_US_POSIX").date(from: date)
    }

    /// `"TODAY"` / `"YESTERDAY"` for the two most recent UTC days, else weekday.
    private static func title(for date: String) -> String {
        let cal = Calendar.gmt
        if date == dayString(Date()) { return "TODAY" }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: Date()),
           date == dayString(yesterday) { return "YESTERDAY" }
        guard let day = utcMidnight(from: date) else { return date }
        return formatter("EEE", locale: "en_US").string(from: day).uppercased()
    }

    private static func dateLabel(for date: String) -> String {
        guard let day = utcMidnight(from: date) else { return date }
        return formatter("EEE · dd MMM", locale: "en_US").string(from: day).uppercased()
    }

    private static func dayString(_ date: Date) -> String {
        formatter("yyyy-MM-dd", locale: "en_US_POSIX").string(from: date)
    }

    private static func formatter(_ format: String, locale: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .gmt
        f.locale = Locale(identifier: locale)
        f.dateFormat = format
        return f
    }
}
