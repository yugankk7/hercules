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
        let cards = CardKind.allCases.map { kind in
            switch kind {
            case .dailyActivity:
                ActivityCardFormat.card(from: activity)
            default:
                DashboardCard(kind: kind, state: .empty)
            }
        }
        return DashboardSnapshot(cards: cards, freshness: freshness())
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
