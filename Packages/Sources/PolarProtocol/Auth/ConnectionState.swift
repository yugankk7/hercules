import Foundation

/// Coarse auth status that routes the app between onboarding and dashboard.
/// Derived from `TokenStore` contents at launch (see `AuthManager.bootstrap()`);
/// a failed v4 refresh transitions to `reauthRequired`.
public enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reauthRequired
}
