import AuthenticationServices
import Foundation
import UIKit

/// Abstracts `ASWebAuthenticationSession` so the OAuth flow is unit-testable.
@MainActor
public protocol WebAuthPresenting: Sendable {
    /// Present `url` in a secure browser and return the captured callback URL.
    func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

/// Live `ASWebAuthenticationSession` driver. Uses an **ephemeral** session and
/// serves as its own presentation-context anchor (Safeguard 3 / Safeguard 7).
@MainActor
public final class WebAuthSession: NSObject, WebAuthPresenting, ASWebAuthenticationPresentationContextProviding {

    public override init() { super.init() }

    public func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    if let asError = error as? ASWebAuthenticationSessionError,
                       asError.code == .canceledLogin {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: AuthError.network("web auth session failed"))
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.network("missing callback URL"))
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            if !session.start() {
                continuation.resume(throwing: AuthError.network("could not start web auth session"))
            }
        }
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            // A session is only presented while the app is foreground, so an
            // active window scene always exists at this point.
            preconditionFailure("web auth session presented with no active window scene")
        }
        // Prefer the existing key window; otherwise anchor to the scene directly.
        return scene.keyWindow ?? UIWindow(windowScene: scene)
    }
}
