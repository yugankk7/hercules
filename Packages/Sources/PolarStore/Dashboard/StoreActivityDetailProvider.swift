import Foundation
import PolarProtocol

/// `StoreReading`-backed `ActivityDetailProviding` (HERC-061): assembles the Daily
/// Activity detail for the most recent `activity_day` from the local store, zero
/// network. Derives the zone breakdown and the intensity density band from the
/// per-minute `activity_zones` series, and the hero HR curve from `hr_minute` sliced
/// to that UTC day. Absent data → `nil` (the screen shows its empty state).
public struct StoreActivityDetailProvider: ActivityDetailProviding {
    private let store: any StoreReading

    /// 144 ten-minute buckets across 24h — the design's band resolution.
    private static let buckets = 144
    private static let secondsPerDay: TimeInterval = 86_400

    public init(store: any StoreReading) {
        self.store = store
    }

    public func availableDays() async -> [String] {
        ((try? store.activityDates()) ?? [])
    }

    public func detail(for date: String) async -> ActivityDetail? {
        guard let day = (try? store.activityDay(date: date)) ?? nil,
              let dayStart = Self.utcMidnight(from: day.date) else { return nil }

        let dayEnd = dayStart.addingTimeInterval(Self.secondsPerDay)
        let minutes = (try? store.heartRateMinutes(in: DateInterval(start: dayStart, end: dayEnd))) ?? []
        let hr = minutes.map { m in
            ActivityHRSample(hour: m.minute.timeIntervalSince(dayStart) / 3600, bpm: m.avg)
        }

        let breakdown = Self.zoneBreakdown(day.zones)
        return ActivityDetail(
            title: Self.title(for: day.date),
            dateLabel: Self.dateLabel(for: dayStart),
            steps: day.steps,
            distanceKm: day.distance / 1000,
            activeMinutes: Int((day.activeDuration / 60).rounded()),
            calories: day.calories,
            dailyActivityPct: day.dailyActivity,
            inactivityCount: day.inactivityAlerts,
            awakeMinutes: breakdown.reduce(0) { $0 + $1.minutes },
            zones: breakdown,
            intensity: Self.intensityBand(day.zones, dayStart: dayStart),
            hr: hr,
            sleepBlock: Self.sleepBlock(day.zones, dayStart: dayStart)
        )
    }

    // MARK: - Zone derivation

    /// Polar's six intensity classes collapse onto the five-slice awake ramp. SLEEP
    /// and NON_WEAR are excluded (they aren't "awake" time); we have no distinct
    /// resting class, so REST stays empty — matching the design's `rest:0` days.
    private static func rampLevel(_ zone: ActivityZoneKind) -> Int? {
        switch zone {
        case .sedentary: 1   // SIT
        case .light:     2   // LOW
        case .moderate:  3   // MED
        case .vigorous:  4   // HIGH
        case .sleep, .nonWear, .unknown: nil
        }
    }

    private static func zoneBreakdown(_ samples: [ActivityZoneSample]) -> [ActivityZoneSlice] {
        var minutes = [0, 0, 0, 0, 0]   // REST, SIT, LOW, MED, HIGH
        for sample in samples {
            if let level = rampLevel(sample.zone) { minutes[level] += 1 }
        }
        let names = ["REST", "SIT", "LOW", "MED", "HIGH"]
        return names.enumerated().map { ActivityZoneSlice(name: $1, level: $0, minutes: minutes[$0]) }
    }

    /// Bucket the per-minute zone labels to the band's resolution, taking the peak
    /// level seen in each bucket so brief vigorous bursts stay visible.
    private static func intensityBand(_ samples: [ActivityZoneSample], dayStart: Date) -> [Int] {
        var band = [Int](repeating: 0, count: buckets)
        let bucketSeconds = secondsPerDay / Double(buckets)
        for sample in samples {
            guard let level = rampLevel(sample.zone) else { continue }
            let offset = sample.minute.timeIntervalSince(dayStart)
            guard offset >= 0, offset < secondsPerDay else { continue }
            let i = Int(offset / bucketSeconds)
            band[i] = max(band[i], level)
        }
        return band
    }

    /// The leading night-sleep block: the span of SLEEP-labelled minutes that fall in
    /// the morning half of the day, expressed in fractional hours from midnight.
    private static func sleepBlock(_ samples: [ActivityZoneSample], dayStart: Date) -> ClosedRange<Double>? {
        let sleepHours = samples.compactMap { sample -> Double? in
            guard case .sleep = sample.zone else { return nil }
            let hour = sample.minute.timeIntervalSince(dayStart) / 3600
            return (0..<12).contains(hour) ? hour : nil
        }
        guard let last = sleepHours.max() else { return nil }
        return 0...max(last, 0.1)
    }

    // MARK: - Date formatting

    private static func utcMidnight(from date: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .gmt
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: date)
    }

    private static func title(for date: String) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        let today = todayString(cal: cal)
        if date == today { return "TODAY" }
        guard let day = utcMidnight(from: date) else { return date }
        let f = DateFormatter()
        f.timeZone = .gmt
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE"
        return f.string(from: day).uppercased()
    }

    private static func todayString(cal: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = .gmt
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func dateLabel(for day: Date) -> String {
        let f = DateFormatter()
        f.timeZone = .gmt
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE · dd MMM"
        return f.string(from: day).uppercased()
    }
}
