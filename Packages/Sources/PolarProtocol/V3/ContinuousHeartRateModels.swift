import Foundation

/// A single continuous-HR sample with an absolute timestamp. **Built in the
/// client** by pairing each day's `date` with the per-sample time-of-day
/// (`sample_time` is `"HH:mm:ss"` only). A decode intermediate — never returned;
/// the client buckets these to `HeartRateMinute` and releases the array, so
/// ≈16 MB / 28 d never escapes the decode scope (Safeguard 2).
public struct HeartRateSample: Sendable, Equatable {
    public let timestamp: Date
    public let heartRate: Int

    public init(timestamp: Date, heartRate: Int) {
        self.timestamp = timestamp
        self.heartRate = heartRate
    }
}

/// A per-minute HR bucket — the client's product for continuous HR. Maps to the
/// eventual `hr_minute` table (Epic 4).
public struct HeartRateMinute: Sendable, Equatable {
    public let minute: Date
    public let min: Int
    public let avg: Int
    public let max: Int

    public init(minute: Date, min: Int, avg: Int, max: Int) {
        self.minute = minute
        self.min = min
        self.avg = avg
        self.max = max
    }
}
