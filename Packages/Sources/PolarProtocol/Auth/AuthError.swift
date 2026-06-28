import Foundation

/// The single typed error currency across the auth layer. Cases carry only
/// minimal context (status codes, denied scopes) — **never tokens or secrets**.
/// `AuthManager.connect()` is the one place these are caught and mapped to
/// user-facing onboarding state.
public enum AuthError: Error, Equatable, Sendable {
    /// The user dismissed the secure web session.
    case cancelled
    /// Neither the Keychain nor a bundled `Secrets.plist` held usable credentials.
    case missingSecrets
    /// A transport-level failure; the string is a redaction-safe summary only.
    case network(String)
    /// A token exchange returned a non-2xx status.
    case tokenExchangeFailed(Int)
    /// A v4 refresh-token exchange failed; full re-auth is required.
    case refreshFailed
    /// One-time user registration returned an unexpected non-2xx status.
    case registrationFailed(Int)
    /// The authorize round granted fewer scopes than requested.
    case scopeDenied([String])
    /// A data request returned a non-2xx status; carries only the status code.
    case httpStatus(Int)
    /// A response body failed to decode; carries a redaction-safe summary only —
    /// **never** the raw body.
    case decoding(String)
}
