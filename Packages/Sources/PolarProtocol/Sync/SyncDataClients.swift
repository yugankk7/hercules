import Foundation

/// The authenticated v3/v4 data clients the sync engine fetches through, bundled
/// as one `Sendable` value. Vended by `AuthManager.makeDataClients()` so the
/// private token store / config stay encapsulated. The clients' transports read
/// the live token store dynamically, so the bundle stays valid across token
/// refreshes and re-auth.
public struct SyncDataClients: Sendable {
    public let v3: V3DataClient
    public let v4: V4DataClient

    public init(v3: V3DataClient, v4: V4DataClient) {
        self.v3 = v3
        self.v4 = v4
    }
}
