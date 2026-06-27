import Foundation

/// Outcome of the one-time user registration.
public enum RegistrationResult: Sendable, Equatable {
    /// First-run registration succeeded (`201`); carries `x_user_id` if returned.
    case registered(userID: String?)
    /// The user was already registered (conflict) — a no-op success.
    case alreadyRegistered
}

/// One-time, **idempotent** `POST /v3/users` registration. Safe to call on every
/// connect: `201` registers, a `409` conflict is treated as already-registered,
/// any other non-2xx throws `AuthError.registrationFailed(status)`.
public struct UserRegistrationService: Sendable {
    /// Fixed v3 AccessLink registration endpoint (see `ARCHITECTURE.md` §7).
    private static let usersEndpoint = URL(string: "https://www.polaraccesslink.com/v3/users")!

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func register(memberID: String, credential: V3Credential) async throws -> RegistrationResult {
        var request = URLRequest(url: Self.usersEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["member-id": memberID])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network("registration request failed")
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        switch status {
        case 200, 201:
            return .registered(userID: parseUserID(data))
        case 409:
            return .alreadyRegistered
        default:
            throw AuthError.registrationFailed(status)
        }
    }

    /// Capture `polar-user-id` from the registration profile if present.
    private func parseUserID(_ data: Data) -> String? {
        guard let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        if let n = dict["polar-user-id"] as? Int { return String(n) }
        return dict["polar-user-id"] as? String
    }
}
