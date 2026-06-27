import Foundation

/// How fresh the dashboard data is. Presentation (e.g. "SYNCED 2M AGO") is
/// computed in the view, never stored here.
public enum SyncFreshness: Sendable, Equatable {
    case neverSynced
    case syncedAt(Date)
}
