import Foundation

/// A registered device, assembled from `GET /v4/data/user-devices`. Verified
/// against a live capture (2026-06-28): the response splits device facts across
/// `devicesData[]` (firmware, color, hardware id) and
/// `userDevicesData.activeDevices[]` (registration + `deviceSettings`), joined by
/// `deviceReference.uuid`. **Battery is intentionally absent** (deferred to BLE,
/// phase 2) — not a decode failure. Maps to the eventual `device` table.
///
/// This is a flattened view built by `V4DataClient`, not decoded directly.
public struct Device: Sendable, Equatable {
    public let uuid: String
    public let firmware: String?
    public let color: String?
    public let productDescription: String?
    public let hardwareIdentifier: String?
    public let registered: Date?
    /// Resolved from the `deviceSettings` name/value list (value `"ON"` → `true`).
    public let automaticTrainingDetection: Bool?

    public init(
        uuid: String,
        firmware: String? = nil,
        color: String? = nil,
        productDescription: String? = nil,
        hardwareIdentifier: String? = nil,
        registered: Date? = nil,
        automaticTrainingDetection: Bool? = nil
    ) {
        self.uuid = uuid
        self.firmware = firmware
        self.color = color
        self.productDescription = productDescription
        self.hardwareIdentifier = hardwareIdentifier
        self.registered = registered
        self.automaticTrainingDetection = automaticTrainingDetection
    }
}
