import Foundation

/// Decode-only client for the narrow AccessLink **v4** surface (Epic 3): the only
/// three v4 endpoints we use — workout history, sports catalog, devices. **Every**
/// call routes through the existing `RefreshAwareV4Client` actor (Safeguard 4);
/// this client owns no `URLSession`. Returns models only — caching and
/// orchestration are Epics 4/5. Wire shapes verified against live captures
/// (2026-06-28).
///
/// `training-sessions/list` uses the **naive datetime** dialect and is sent
/// **without** a `features` param (it 400s otherwise); the other two take no dates.
public struct V4DataClient: Sendable {
    /// Fixed v4 data base URL (`ARCHITECTURE.md` §7). Centralized — never at call sites.
    private static let base = "https://www.polaraccesslink.com/v4/data"

    private let transport: RefreshAwareV4Client

    public init(transport: RefreshAwareV4Client) {
        self.transport = transport
    }

    /// `GET /training-sessions/list?from=&to=` (naive datetime, **no `features`**).
    /// Envelope: `{ trainingSessions: [...] }`.
    public func fetchTrainingSessions(_ window: DateWindow) async throws -> [TrainingSession] {
        let data = try await get(path: "/training-sessions/list", query: window.naiveDateTimeParams())
        return try decodeList(data) { (e: TrainingSessionEnvelope) in e.sessions }
    }

    /// `GET /sports/list` (no dates) → **top-level array** of `id → name`.
    public func fetchSports() async throws -> [Sport] {
        let data = try await get(path: "/sports/list")
        guard !data.isEmpty else { return [] }
        return try decode([Sport].self, from: data)
    }

    /// `GET /user-devices` (no dates). Joins `devicesData[]` (firmware/color) with
    /// `userDevicesData.activeDevices[]` (registration/settings) by uuid. Battery
    /// is expected-absent, not an error.
    public func fetchDevices() async throws -> [Device] {
        let data = try await get(path: "/user-devices")
        guard !data.isEmpty else { return [] }
        return try decode(UserDevicesDTO.self, from: data).devices()
    }

    // MARK: - Transport + decoding helpers

    /// Build a v4 GET and run it through the refresh-aware actor; map non-2xx.
    private func get(path: String, query: [URLQueryItem] = []) async throws -> Data {
        guard var comps = URLComponents(string: Self.base + path) else {
            throw AuthError.network("v4 malformed URL")
        }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw AuthError.network("v4 malformed URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await transport.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            print("[v4] \(path) failed: status=\(status)")
            throw AuthError.httpStatus(status)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder.polar().decode(T.self, from: data)
        } catch {
            throw AuthError.decoding("v4 \(T.self) decode failed")
        }
    }

    private func decodeList<E: Decodable, T>(_ data: Data, _ project: (E) -> [T]) throws -> [T] {
        guard !data.isEmpty else { return [] }
        return project(try decode(E.self, from: data))
    }
}

// MARK: - Response envelopes (private to the client)

private struct TrainingSessionEnvelope: Decodable {
    let sessions: [TrainingSession]
    enum CodingKeys: String, CodingKey { case sessions = "trainingSessions" }
}

/// Wire shape of `GET /user-devices` — flattened into `[Device]` by joining the
/// two blocks on `deviceReference.uuid`.
private struct UserDevicesDTO: Decodable {
    let devicesData: [DeviceData]?
    let userDevicesData: UserData?

    struct DeviceData: Decodable {
        let deviceReference: Reference?
        let firmwareVersion: String?
        let hardwareIdentifier: String?
        let productVariant: ProductVariant?
    }
    struct ProductVariant: Decodable {
        let productColor: String?
        let productDescription: String?
    }
    struct UserData: Decodable {
        let activeDevices: [ActiveDevice]?
    }
    struct ActiveDevice: Decodable {
        let deviceReference: Reference?
        let registered: Date?
        let deviceSettings: [Setting]?
    }
    struct Reference: Decodable { let uuid: String? }
    struct Setting: Decodable { let name: String?; let value: String? }

    /// Join the two blocks by uuid into the flattened `Device` view.
    func devices() -> [Device] {
        let active = userDevicesData?.activeDevices ?? []
        return (devicesData ?? []).compactMap { d in
            guard let uuid = d.deviceReference?.uuid else { return nil }
            let match = active.first { $0.deviceReference?.uuid == uuid }
            let autoDetect = match?.deviceSettings?
                .first { $0.name == "automaticTrainingDetection" }
                .map { $0.value?.uppercased() == "ON" }
            return Device(
                uuid: uuid,
                firmware: d.firmwareVersion,
                color: d.productVariant?.productColor,
                productDescription: d.productVariant?.productDescription,
                hardwareIdentifier: d.hardwareIdentifier,
                registered: match?.registered,
                automaticTrainingDetection: autoDetect
            )
        }
    }
}
