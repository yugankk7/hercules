import Foundation

/// Namespace for the Polar AccessLink data layer (API models + clients).
///
/// Phase 1 talks to AccessLink **v3** (primary) and **v4** (workouts / devices /
/// sports). Phase 2 adds the Polar BLE SDK. See `ARCHITECTURE.md`.
public enum PolarProtocol {
    /// Marketing version of the data layer, surfaced for diagnostics.
    public static let version = "0.1.0"
}
