import Foundation
import PolarProtocol

/// `StoreReading`-backed `DashboardProviding` (HERC-042 / HERC-061): builds the
/// home feed from the local store, zero network (Safeguard 3). This is the first
/// real provider — it replaces `StubDashboardProvider` in the connected app.
///
/// This slice populates the **Daily Activity** card from the latest `activity_day`
/// row; the remaining seven cards stay `.empty` until their own feature slices land
/// (each will fill in its own glance then, the same way this one does). Card content
/// rides on the existing `headline`/`detail` strings — no per-domain fields are
/// added to `DashboardCard` (Data constraint, Safeguard 8).
public struct StoreDashboardProvider: DashboardProviding {
    private let store: any StoreReading

    public init(store: any StoreReading) {
        self.store = store
    }

    public func snapshot() async -> DashboardSnapshot {
        // Reads never throw to the UI: a failed read degrades to the `.empty`
        // first-run state, never an error (Norm 5).
        let activity = try? store.latestActivityDay()
        let sleep = latestSleepNight()
        let boost = latestSleepwiseDay()
        let nightsLogged = (try? store.sleepwiseNightsLogged()) ?? 0
        let cards = CardKind.allCases.map { kind in
            switch kind {
            case .dailyActivity:
                ActivityCardFormat.card(from: activity)
            case .sleep:
                SleepCardFormat.card(from: sleep)
            case .boostFromSleep:
                BoostCardFormat.card(from: boost, nightsLogged: nightsLogged)
            default:
                DashboardCard(kind: kind, state: .empty)
            }
        }
        return DashboardSnapshot(cards: cards, freshness: freshness())
    }

    /// The most-recent stored sleep night, or `nil` (degrades to `.empty`).
    private func latestSleepNight() -> SleepNightView? {
        guard let date = (try? store.sleepDates())?.first else { return nil }
        return (try? store.sleepNight(date: date)) ?? nil
    }

    /// The most-recent merged SleepWise night, or `nil` (degrades to `.empty`).
    private func latestSleepwiseDay() -> SleepwiseDayView? {
        guard let date = (try? store.sleepwiseDates())?.first else { return nil }
        return (try? store.sleepwiseDay(date: date)) ?? nil
    }

    /// Feed freshness is the most-recent successful sync across **all** domains —
    /// the truthful "SYNCED X AGO" even before every card is wired. None synced yet
    /// → `.neverSynced`.
    private func freshness() -> SyncFreshness {
        let latest = SyncDomain.allCases
            .compactMap { (try? store.lastSync(domain: $0.rawValue)) ?? nil }
            .max()
        return latest.map(SyncFreshness.syncedAt) ?? .neverSynced
    }
}

/// Display formatting for the Daily Activity card glance. Lives with the provider
/// because the card contract carries display-ready strings (the view just renders
/// `headline`/`detail`). Uses a fixed `en_US` locale so the instrument-style
/// grouping ("8,432") is deterministic regardless of device locale.
enum ActivityCardFormat {

    /// Steps as the headline; calories · distance · active-time as the detail —
    /// matching the activity card brief in `SCREENS_AND_FEATURES.md` §2. Absent
    /// data is the designed first-run `.empty` state.
    static func card(from day: ActivityDayView?) -> DashboardCard {
        guard let day else {
            return DashboardCard(kind: .dailyActivity, state: .empty)
        }
        return DashboardCard(
            kind: .dailyActivity,
            state: .populated,
            headline: "\(grouped(day.steps)) STEPS",
            detail: detail(day)
        )
    }

    private static func detail(_ day: ActivityDayView) -> String {
        var parts = ["\(grouped(day.calories)) KCAL"]
        if day.distance > 0 { parts.append(kilometres(day.distance)) }
        if day.activeDuration > 0 { parts.append("\(hoursMinutes(day.activeDuration)) ACTIVE") }
        return parts.joined(separator: " · ")
    }

    private static let groupingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    private static func grouped(_ value: Int) -> String {
        groupingFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Metres → one-decimal kilometres, e.g. `6100 → "6.1 KM"`.
    private static func kilometres(_ metres: Double) -> String {
        String(format: "%.1f KM", metres / 1000)
    }

    /// Seconds → `"1H 23M"`, dropping the hours component below an hour (`"23M"`).
    private static func hoursMinutes(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)H \(minutes)M" : "\(minutes)M"
    }
}

/// Display formatting for the SLEEP card glance (mirrors `ActivityCardFormat`).
/// Fixed `en_US` locale; absent data is the designed first-run `.empty`.
enum SleepCardFormat {

    /// Score as the headline; sleep duration · continuity class as the detail.
    static func card(from night: SleepNightView?) -> DashboardCard {
        guard let night else { return DashboardCard(kind: .sleep, state: .empty) }
        let asleep = [night.stages.light, night.stages.deep, night.stages.rem]
            .compactMap { $0 }.reduce(0, +) / 60
        let headline = night.score.map { "\($0) SCORE" } ?? "\(hoursMinutes(asleep)) SLEEP"
        var parts = [hoursMinutes(asleep)]
        if let continuityClass = night.continuityClass {
            parts.append("CONTINUITY \(continuityClass)/3")
        }
        return DashboardCard(kind: .sleep, state: .populated, headline: headline,
                             detail: parts.joined(separator: " · "))
    }

    /// Minutes → `"7H 15M"`.
    private static func hoursMinutes(_ minutes: Int) -> String {
        "\(minutes / 60)H \(String(format: "%02d", minutes % 60))M"
    }
}

/// Display formatting for the BOOST card glance. Below the calibration threshold
/// the glance is `.calibrating`; a forecast night is `.populated`; absent is
/// `.empty`.
enum BoostCardFormat {

    static func card(from day: SleepwiseDayView?, nightsLogged: Int,
                     calibrationTarget: Int = 14) -> DashboardCard {
        guard let day else { return DashboardCard(kind: .boostFromSleep, state: .empty) }
        if nightsLogged < calibrationTarget {
            return DashboardCard(
                kind: .boostFromSleep, state: .calibrating,
                headline: "CALIBRATING", detail: "NIGHTS LOGGED \(nightsLogged) / \(calibrationTarget)"
            )
        }
        guard let grade = day.grade else {
            return DashboardCard(kind: .boostFromSleep, state: .empty)
        }
        return DashboardCard(
            kind: .boostFromSleep, state: .populated,
            headline: String(format: "%.1f/10 BOOST", grade),
            detail: day.classification?.label ?? "FORECAST"
        )
    }
}
