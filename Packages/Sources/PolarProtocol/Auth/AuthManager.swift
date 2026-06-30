import Foundation
import Observation

/// Orchestrates the two-realm connect flow and publishes onboarding state for
/// the UI. `connect()` is the **single catch site** that maps `AuthError` →
/// onboarding state (Norm 3). The whole connect sequence is atomic: partial
/// (one-realm) success never reports `connected` (Safeguard 1).
@MainActor
@Observable
public final class AuthManager {

    public private(set) var state: ConnectionState
    public private(set) var step: OnboardingStep
    public private(set) var lastError: AuthError?
    /// Fractional initial-sync progress (0→1), bound by `InitialSyncView`.
    public private(set) var syncProgress: Double = 0

    private let oauth: any OAuthClienting
    private let store: any TokenStoring
    private let registration: UserRegistrationService
    private let sync: any InitialSyncProviding
    private let memberID: String
    private let v3Config: RealmConfig
    private let v4Config: RealmConfig

    public init(
        oauth: any OAuthClienting,
        store: any TokenStoring,
        registration: UserRegistrationService,
        sync: any InitialSyncProviding,
        memberID: String,
        v3Config: RealmConfig,
        v4Config: RealmConfig,
        initialError: AuthError? = nil
    ) {
        self.oauth = oauth
        self.store = store
        self.registration = registration
        self.sync = sync
        self.memberID = memberID
        self.v3Config = v3Config
        self.v4Config = v4Config
        self.state = .disconnected
        self.step = .welcome
        self.lastError = initialError
    }

    /// Derive initial state from stored credentials — both present ⇒ `connected`.
    public func bootstrap() {
        let hasV3 = (try? store.loadV3()) != nil
        let hasV4 = (try? store.loadV4()) != nil
        if hasV3 && hasV4 {
            state = .connected
            step = .done
        } else {
            state = .disconnected
        }
    }

    /// Atomic two-realm connect: v3 then v4, register, then stubbed initial sync.
    public func connect() async {
        lastError = nil
        state = .connecting
        do {
            // --- v3: long-lived bearer ---
            step = .handoff
            let code3 = try await oauth.authorize(v3Config)
            let dto3 = try await oauth.exchange(code: code3, v3Config)
            var v3 = dto3.v3Credential()
            try store.saveV3(v3)

            // --- v4: access + refresh pair (full scope set, one consent) ---
            let code4 = try await oauth.authorize(v4Config)
            let dto4 = try await oauth.exchange(code: code4, v4Config)
            let v4 = dto4.v4Pair(requestedScopes: v4Config.scopes)
            try store.saveV4(v4)
            print("[Auth] v4 granted scopes: \(v4.grantedScopes.joined(separator: " "))")

            // --- one-time, idempotent registration ---
            step = .authorizing
            switch try await registration.register(memberID: memberID, credential: v3) {
            case .registered(let userID):
                print("[Auth] registration: registered")
                if let userID {
                    v3.userID = userID
                    try store.saveV3(v3)
                }
            case .alreadyRegistered:
                print("[Auth] registration: alreadyRegistered")
            }

            // --- stubbed initial sync (real engine: EPIC 5) ---
            step = .syncing
            syncProgress = 0
            try await sync.run { [weak self] p in
                Task { @MainActor in self?.syncProgress = p }
            }

            step = .done
            state = .connected
        } catch let error as AuthError {
            handle(error)
        } catch {
            handle(.network("unexpected error"))
        }
    }

    /// User cancelled the secure session — return to consent with no partial state.
    public func cancel() {
        try? store.clearAll()
        state = .disconnected
        step = .consent
        syncProgress = 0
    }

    /// Sign out — clear all credentials and return to the welcome screen.
    public func signOut() {
        try? store.clearAll()
        state = .disconnected
        step = .welcome
        syncProgress = 0
    }

    // MARK: - The single error mapping site

    private func handle(_ error: AuthError) {
        print("[Auth] connect failed at step \(step): \(error)")
        switch error {
        case .cancelled:
            // Back to consent; no partial credential state.
            state = .disconnected
            step = .consent
        case .refreshFailed:
            // Refresh exhausted → clean re-auth path.
            state = .reauthRequired
            lastError = error
        default:
            // Recoverable: surface a banner, keep the user on consent to retry.
            state = .disconnected
            step = .consent
            lastError = error
        }
    }
}

public extension AuthManager {
    /// Build the production `AuthManager` with live dependencies. If secrets are
    /// missing it returns a manager primed with `.missingSecrets` so the UI can
    /// surface a clean error rather than crashing.
    static func live() -> AuthManager {
        let store = TokenStore()
        let web = WebAuthSession()
        let oauth = OAuthClient(web: web)
        let registration = UserRegistrationService()
        let sync = StubInitialSyncProvider()

        do {
            let secrets = try AppSecrets.load()
            return AuthManager(
                oauth: oauth,
                store: store,
                registration: registration,
                sync: sync,
                memberID: secrets.memberID,
                v3Config: .v3(secrets: secrets),
                v4Config: .v4(secrets: secrets)
            )
        } catch {
            let empty = AppSecrets(clientID: "", clientSecret: "", memberID: "")
            return AuthManager(
                oauth: oauth,
                store: store,
                registration: registration,
                sync: sync,
                memberID: "",
                v3Config: .v3(secrets: empty),
                v4Config: .v4(secrets: empty),
                initialError: .missingSecrets
            )
        }
    }

    /// Vend the authenticated v3/v4 data clients the Epic 5 sync engine fetches
    /// through. Lives on `AuthManager` because the token `store`, `oauth`, and
    /// `v4Config` are private — this seam keeps auth encapsulated while handing
    /// out ready-to-use clients. The transports resolve the live token store on
    /// each call, so the returned bundle survives refresh / re-auth.
    func makeDataClients() -> SyncDataClients {
        let v3 = V3DataClient(transport: V3Transport(store: store))
        let v4 = V4DataClient(
            transport: RefreshAwareV4Client(store: store, oauth: oauth, config: v4Config)
        )
        return SyncDataClients(v3: v3, v4: v4)
    }
}
