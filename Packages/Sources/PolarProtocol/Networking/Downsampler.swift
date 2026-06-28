import Foundation

/// Pure per-minute bucketing so raw high-frequency arrays **never escape a
/// client** (Safeguard 2). Continuous HR arrives at ~5-sec resolution
/// (≈16 MB / 28 d); a client decodes it, buckets here, and returns only the
/// minute rows — the raw array is released within the decode scope, keeping peak
/// memory bounded on multi-day pulls. No I/O, no shared state.
public enum Downsampler {
    /// Bucket raw HR samples into per-minute `min` / `avg` (rounded) / `max`,
    /// ascending by minute. Tolerates gaps and partial minutes — no fixed sample
    /// count per minute is assumed.
    public static func heartRateMinutes(_ samples: [HeartRateSample]) -> [HeartRateMinute] {
        guard !samples.isEmpty else { return [] }

        var buckets: [Date: (min: Int, max: Int, sum: Int, count: Int)] = [:]
        for s in samples {
            let minute = s.timestamp.flooredToMinute()
            if var b = buckets[minute] {
                b.min = Swift.min(b.min, s.heartRate)
                b.max = Swift.max(b.max, s.heartRate)
                b.sum += s.heartRate
                b.count += 1
                buckets[minute] = b
            } else {
                buckets[minute] = (s.heartRate, s.heartRate, s.heartRate, 1)
            }
        }

        return buckets.keys.sorted().map { key in
            let b = buckets[key]!
            let avg = Int((Double(b.sum) / Double(b.count)).rounded())
            return HeartRateMinute(minute: key, min: b.min, avg: avg, max: b.max)
        }
    }

    /// Aggregate step samples into per-minute totals keyed on the floored-minute
    /// timestamp. Inputs are typically already at a 60 000 ms interval; any finer
    /// samples are summed into their minute. `interval` is the source sample
    /// spacing (informational; bucketing is driven by the timestamps).
    public static func stepMinutes(_ raw: [RawStepSample], interval: TimeInterval = 60) -> [StepMinute] {
        guard !raw.isEmpty else { return [] }

        var buckets: [Date: Int] = [:]
        for s in raw {
            buckets[s.minute.flooredToMinute(), default: 0] += s.steps
        }
        return buckets.keys.sorted().map { StepMinute(minute: $0, steps: buckets[$0]!) }
    }
}

extension Date {
    /// Truncate to the start of the containing UTC minute (stable bucket key).
    func flooredToMinute() -> Date {
        Date(timeIntervalSince1970: (timeIntervalSince1970 / 60).rounded(.down) * 60)
    }
}
