import Foundation

/// The two Polar OAuth realms Hercules authenticates against in a single
/// `connect()` operation. They **share one client pair** but use different
/// authorize/token hosts and yield different token shapes (see `RealmConfig`).
public enum AuthRealm: String, Sendable, CaseIterable {
    /// AccessLink v3 — long-lived (~10 yr) bearer, no refresh.
    case v3
    /// v4 — short-lived access token (1 h) + refresh token (~100 d).
    case v4
}
