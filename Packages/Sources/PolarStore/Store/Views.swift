import Foundation
import PolarProtocol

/// Display-ready projections returned by `StoreReading` — `*_json` columns are
/// already rehydrated (maps/arrays/enums restored) so the UI never parses JSON.
/// Read-only value types, constructed by the store from records.

/// `activity_day` row + decoded per-minute zone series.
public struct ActivityDayView: Sendable, Equatable {
    public let date: String
    public let startTime: Date?
    public let endTime: Date?
    public let steps: Int
    public let calories: Int
    public let activeCalories: Int
    public let activeDuration: Double
    public let inactiveDuration: Double
    public let dailyActivity: Int
    public let distance: Double
    public let inactivityAlerts: Int
    public let zones: [ActivityZoneSample]
}

/// `sleep_night` row + decoded stage totals, hypnogram, and HR-sample maps.
public struct SleepNightView: Sendable, Equatable {
    public let date: String
    public let score: Int?
    public let stages: SleepStagesDTO
    public let hypnogram: [String: Int]
    public let hrSamples: [String: Int]
    public let continuity: Double?
    public let continuityClass: Int?
    public let charge: Int?
    public let cycles: Int?
    public let startTime: Date?
    public let endTime: Date?
}

/// `sleepwise_day` row + restored enums, hourly buckets, and gate/window ranges
/// (fractional **local** hours, anchored via the stored `tzOffsetMinutes`). One
/// merged alertness + circadian night keyed by wake-day.
public struct SleepwiseDayView: Sendable, Equatable {
    public let date: String
    public let grade: Double?
    public let classification: GradeClass?
    public let validity: Validity
    public let inertia: SleepInertia?
    public let hourly: [AlertnessHour]
    /// Sleep gate window in fractional local hours (`nil` when circadian absent).
    public let gate: ClosedRange<Double>?
    /// Preferred sleep window in fractional local hours (`nil` when circadian absent).
    public let window: ClosedRange<Double>?
    public let quality: BedtimeQuality?
    /// The single authoritative offset (from the alertness entry) used to localise
    /// all of the night's UTC times.
    public let tzOffsetMinutes: Int
}

/// `recharge` row + decoded HRV / breathing sample maps.
public struct RechargeView: Sendable, Equatable {
    public let date: String
    public let ansCharge: Double?
    public let ansChargeStatus: Int?
    public let nightlyRechargeStatus: Int?
    public let hrAvg: Double?
    public let hrvAvg: Double?
    public let breathingAvg: Double?
    public let beatToBeatAvg: Double?
    public let hrvSamples: [String: Double]
    public let breathingSamples: [String: Double]
}

/// `cardio_load` row + restored status enum and level breakdown.
public struct CardioLoadView: Sendable, Equatable {
    public let date: String
    public let strain: Double
    public let tolerance: Double
    public let ratio: Double
    public let cardioLoad: Double
    public let status: CardioLoadStatus
    public let level: CardioLoadLevel?
}

/// `training_session` row + read-time resolved sport name and decoded macros.
public struct TrainingSessionView: Sendable, Equatable {
    public let id: String
    public let start: Date
    public let stop: Date
    public let sportId: Int
    /// Resolved from `sport_ref` at read time; `nil` if the catalog lacks the id.
    public let sportName: String?
    public let calories: Int?
    public let hrAvg: Int?
    public let hrMax: Int?
    public let benefit: String?
    public let recoveryMs: Int?
    public let durationMs: Int?
    public let distanceM: Double?
    public let note: String?
    public let trigger: String
    public let macros: [Exercise]
}

/// `device` row + decoded settings. Battery intentionally absent (Safeguard 4).
public struct DeviceView: Sendable, Equatable {
    public let uuid: String
    public let firmware: String?
    public let color: String?
    public let productDescription: String?
    public let hardwareIdentifier: String?
    public let registered: Date?
    public let automaticTrainingDetection: Bool?
}
