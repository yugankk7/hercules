import Foundation
import PolarProtocol

/// `StoreReading`-backed `SleepDetailProviding` (HERC-08x): assembles the Sleep
/// Detail day + week models from the local `sleep_night` store, zero network
/// (Safeguard 1). The analogue of `StoreActivityDetailProvider` — all the heavy
/// `"HH:MM"`-map normalisation and 7-night aggregation happen here, off the
/// main-actor read (Safeguard 6); the view receives flat arrays.
public struct StoreSleepDetailProvider: SleepDetailProviding {
    private let store: any StoreReading

    /// Usual-amount reference band (design's "AVG 7H15M"): ±45 min around 7h15m.
    private static let usualAsleepMinutes = 435
    private static let usualBandMinutes = 45

    public init(store: any StoreReading) {
        self.store = store
    }

    public func availableDays() async -> [String] {
        (try? store.sleepDates()) ?? []
    }

    public func detail(for date: String) async -> SleepDetail? {
        guard let night = (try? store.sleepNight(date: date)) ?? nil else {
            return .empty(title: Self.title(for: date), dateLabel: Self.dateLabel(for: date))
        }
        // Anchor on the plotted keys' own local-clock span (not the UTC
        // start/end datetimes, which are on a different clock than the `"HH:MM"`
        // maps). A single `anchor` closure keeps the window, hypnogram, and HR
        // consistent across the midnight boundary.
        let rawHours = night.hypnogram.keys.compactMap(Self.clockHour)
            + night.hrSamples.keys.compactMap(Self.clockHour)
        let wraps = (rawHours.max() ?? 0) - (rawHours.min() ?? 0) > 12
        let anchor: (Double) -> Double = { wraps && $0 < 12 ? $0 + 24 : $0 }
        let window = Self.window(rawHours: rawHours, anchor: anchor, night: night)
        let stages = Self.stageBars(night.stages)
        return SleepDetail(
            title: Self.title(for: night.date),
            dateLabel: Self.dateLabel(for: night.date),
            score: night.score,
            cycles: night.cycles ?? 0,
            continuity: night.continuity,
            continuityClass: night.continuityClass,
            stages: stages,
            hypnogram: Self.hypnogram(night.hypnogram, anchor: anchor, upper: window.upperBound),
            hr: Self.hrSamples(night.hrSamples, anchor: anchor),
            window: window,
            amount: Self.amount(stages),
            isEmpty: false
        )
    }

    public func week(endingAt date: String) async -> SleepWeekDetail? {
        guard let end = Self.utcMidnight(from: date),
              let start = Calendar.gmt.date(byAdding: .day, value: -6, to: end) else {
            return .empty(rangeLabel: date)
        }
        let range = Self.dateString(start)...Self.dateString(end)
        let rangeLabel = Self.rangeLabel(from: start, to: end)
        let nights = (try? store.sleepNights(in: range)) ?? []
        guard !nights.isEmpty else { return .empty(rangeLabel: rangeLabel) }

        // Aggregate over **present** nights only — never `/7` blindly (Safeguard 2).
        let scores = nights.compactMap(\.score)
        let continuities = nights.compactMap(\.continuity)
        let interrupts = nights.compactMap { $0.stages.interruption }.map { $0 / 60 }

        let matrix = nights.map { night -> SleepMatrixNight in
            let bars = Self.stageBars(night.stages)
            return SleepMatrixNight(
                date: night.date, dayLabel: Self.weekday(night.date),
                asleepMinutes: bars.filter { $0.stage != .wake }.reduce(0) { $0 + $1.minutes },
                stages: bars, boost: nil
            )
        }
        let trend = nights.map {
            TrendPoint(date: $0.date, dayLabel: Self.weekday($0.date), score: $0.score, boost: nil)
        }
        return SleepWeekDetail(
            rangeLabel: rangeLabel,
            avgScore: scores.isEmpty ? nil : Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded()),
            avgStages: Self.averageStages(nights),
            avgContinuity: continuities.isEmpty ? nil : continuities.reduce(0, +) / Double(continuities.count),
            avgInterruptMinutes: interrupts.isEmpty ? 0 : interrupts.reduce(0, +) / interrupts.count,
            matrix: matrix, trend: trend, isEmpty: false
        )
    }

    // MARK: - Stage derivation

    /// Flat stage totals (seconds) → the fixed REM/LIGHT/DEEP/AWAKE bar set.
    private static func stageBars(_ stages: SleepStagesDTO) -> [SleepStageBar] {
        [
            SleepStageBar(stage: .rem, minutes: (stages.rem ?? 0) / 60),
            SleepStageBar(stage: .light, minutes: (stages.light ?? 0) / 60),
            SleepStageBar(stage: .deep, minutes: (stages.deep ?? 0) / 60),
            SleepStageBar(stage: .wake, minutes: (stages.interruption ?? 0) / 60),
        ]
    }

    private static func averageStages(_ nights: [SleepNightView]) -> [SleepStageBar] {
        let all = nights.map { stageBars($0.stages) }
        let n = max(all.count, 1)
        return [SleepStage.rem, .light, .deep, .wake].map { stage in
            let total = all.reduce(0) { acc, bars in
                acc + (bars.first { $0.stage == stage }?.minutes ?? 0)
            }
            return SleepStageBar(stage: stage, minutes: total / n)
        }
    }

    private static func amount(_ stages: [SleepStageBar]) -> AmountBracket {
        let asleep = stages.filter { $0.stage != .wake }.reduce(0) { $0 + $1.minutes }
        if asleep < usualAsleepMinutes - usualBandMinutes { return .below }
        if asleep > usualAsleepMinutes + usualBandMinutes { return .above }
        return .on
    }

    // MARK: - Night-anchored axis

    /// Fractional-hour window spanning the anchored hypnogram/HR keys (the local
    /// wall-clock the maps are keyed by — Approach 5, sleep crosses midnight so we
    /// never anchor on 00:00). Falls back to `startTime`/`endTime`, then a default
    /// evening→morning window, only when there are no keys to plot.
    private static func window(rawHours: [Double], anchor: (Double) -> Double,
                              night: SleepNightView) -> ClosedRange<Double> {
        let anchored = rawHours.map(anchor)
        if let lo = anchored.min(), let hi = anchored.max(), hi > lo { return lo...hi }
        if let start = night.startTime, let end = night.endTime, end > start {
            let startHour = fractionalHour(start)
            return startHour...(startHour + end.timeIntervalSince(start) / 3600)
        }
        return 22...34
    }

    /// `"HH:MM"`→stage map → ordered, merged segments on the anchored axis.
    private static func hypnogram(_ map: [String: Int], anchor: (Double) -> Double,
                                 upper: Double) -> [HypnogramSegment] {
        let points = map.compactMap { key, code -> (Double, SleepStage)? in
            guard let h = clockHour(key) else { return nil }
            return (anchor(h), SleepStage(code: code))
        }.sorted { $0.0 < $1.0 }
        guard !points.isEmpty else { return [] }

        var segments: [HypnogramSegment] = []
        for (i, point) in points.enumerated() {
            let end = i + 1 < points.count ? points[i + 1].0 : upper
            if let last = segments.last, last.stage == point.1 {
                segments[segments.count - 1] = HypnogramSegment(
                    startHour: last.startHour, endHour: end, stage: last.stage)
            } else {
                segments.append(HypnogramSegment(startHour: point.0, endHour: end, stage: point.1))
            }
        }
        return segments
    }

    /// `"HH:MM"`→bpm map → samples on the anchored axis, ascending.
    private static func hrSamples(_ map: [String: Int], anchor: (Double) -> Double) -> [SleepHRSample] {
        map.compactMap { key, bpm -> SleepHRSample? in
            guard let h = clockHour(key) else { return nil }
            return SleepHRSample(hour: anchor(h), bpm: bpm)
        }.sorted { $0.hour < $1.hour }
    }

    /// `"HH:MM"` → fractional hour; `nil` if malformed.
    private static func clockHour(_ key: String) -> Double? {
        let parts = key.split(separator: ":")
        guard parts.count == 2, let h = Double(parts[0]), let m = Double(parts[1]) else { return nil }
        return h + m / 60
    }

    private static func fractionalHour(_ date: Date) -> Double {
        let c = Calendar.gmt.dateComponents([.hour, .minute, .second], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
    }

    // MARK: - Date formatting (UTC, en_US — mirrors StoreActivityDetailProvider)

    private static func utcMidnight(from date: String) -> Date? {
        formatter("yyyy-MM-dd", locale: "en_US_POSIX").date(from: date)
    }

    private static func dateString(_ date: Date) -> String {
        formatter("yyyy-MM-dd", locale: "en_US_POSIX").string(from: date)
    }

    private static func title(for date: String) -> String {
        if date == todayString() { return "TODAY" }
        return weekday(date)
    }

    private static func todayString() -> String {
        formatter("yyyy-MM-dd", locale: "en_US_POSIX").string(from: Date())
    }

    /// `"THU"` — weekday abbreviation for a `YYYY-MM-DD` string.
    private static func weekday(_ date: String) -> String {
        guard let day = utcMidnight(from: date) else { return date }
        return formatter("EEE", locale: "en_US").string(from: day).uppercased()
    }

    /// `"THU · 25 JUN"` sublabel for a `YYYY-MM-DD` string.
    private static func dateLabel(for date: String) -> String {
        guard let day = utcMidnight(from: date) else { return date }
        return formatter("EEE · dd MMM", locale: "en_US").string(from: day).uppercased()
    }

    /// `"JUN 22–28"` (same month) or `"JUN 22 – JUL 2"` (spanning months).
    private static func rangeLabel(from start: Date, to end: Date) -> String {
        let cal = Calendar.gmt
        let sameMonth = cal.component(.month, from: start) == cal.component(.month, from: end)
        let startText = formatter(sameMonth ? "MMM dd" : "MMM dd", locale: "en_US").string(from: start)
        let endText = formatter(sameMonth ? "dd" : "MMM dd", locale: "en_US").string(from: end)
        return "\(startText)–\(endText)".uppercased()
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

extension Calendar {
    /// A Gregorian calendar pinned to UTC — the one day boundary the store uses.
    static var gmt: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        return cal
    }
}
