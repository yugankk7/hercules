import Foundation

/// Decode-only client for the AccessLink **v3** surface (Epic 2). One method per
/// endpoint family: compose request → `V3Transport.get` → decode typed model.
/// Returns models and nothing else — no persistence, no orchestration, no
/// range-cap clamping (those are Epics 4/5). Continuous-HR and activity-sample
/// methods down-sample inside the client so raw arrays never escape (Safeguard 2).
///
/// All v3 dates use the **plain `YYYY-MM-DD`** dialect (`PolarDateFormat.dateOnly`).
/// Wire shapes verified against live captures (2026-06-28).
public struct V3DataClient: Sendable {
    private let transport: V3Transport

    public init(transport: V3Transport) {
        self.transport = transport
    }

    // MARK: - Sleep

    /// `GET /users/sleep` → `nights[]`. Empty / no-data ⇒ `[]`.
    public func fetchSleep() async throws -> [SleepNight] {
        let data = try await transport.get(path: "/users/sleep")
        return try decodeList(data) { (e: SleepEnvelope) in e.nights }
    }

    /// `GET /users/sleep/available` → `available[]`. Decode-only manifest.
    public func fetchSleepManifest() async throws -> [SleepAvailability] {
        let data = try await transport.get(path: "/users/sleep/available")
        return try decodeList(data) { (e: SleepManifestEnvelope) in e.available }
    }

    // MARK: - Recharge / cardio load

    /// `GET /users/nightly-recharge` → `recharges[]`; sample objects intact.
    public func fetchNightlyRecharge() async throws -> [NightlyRecharge] {
        let data = try await transport.get(path: "/users/nightly-recharge")
        return try decodeList(data) { (e: RechargeEnvelope) in e.recharges }
    }

    /// `GET /users/cardio-load` → **top-level array** (28 days).
    public func fetchCardioLoad() async throws -> [CardioLoad] {
        let data = try await transport.get(path: "/users/cardio-load")
        guard !data.isEmpty else { return [] }
        return try decode([CardioLoad].self, from: data)
    }

    // MARK: - Continuous HR (down-sampled)

    /// `GET /users/continuous-heart-rate?from=&to=` (dateOnly). The body groups
    /// samples per day under `heart_rates[]`, with time-of-day `sample_time`; we
    /// pair each with its day's `date`, flatten, bucket to per-minute min/avg/max,
    /// and return **only** the buckets — the raw arrays are released here, bounding
    /// peak memory (HERC-023).
    public func fetchContinuousHeartRate(_ window: DateWindow) async throws -> [HeartRateMinute] {
        let data = try await transport.get(
            path: "/users/continuous-heart-rate",
            query: window.dateOnlyParams()
        )
        guard !data.isEmpty else { return [] }
        let days = try decode(ContinuousHeartRateEnvelope.self, from: data).heartRates

        var samples: [HeartRateSample] = []
        for day in days {
            for s in day.heartRateSamples {
                guard let time = s.sampleTime,
                      let ts = PolarDateParser.shared.date(from: "\(day.date)T\(time)") else { continue }
                samples.append(HeartRateSample(timestamp: ts, heartRate: s.heartRate ?? 0))
            }
        }
        return Downsampler.heartRateMinutes(samples)
    }

    // MARK: - Activity

    /// `GET /users/activities?from=&to=` (dateOnly) → **top-level array** of totals.
    public func fetchDailyActivity(_ window: DateWindow) async throws -> [ActivityDay] {
        let data = try await transport.get(path: "/users/activities", query: window.dateOnlyParams())
        guard !data.isEmpty else { return [] }
        return try decode([ActivityDay].self, from: data)
    }

    /// `GET /users/activities/{date}` → a single day's totals (bare object), or
    /// `nil` when the day carries no data (empty `204` body) — days with no wear
    /// are skipped silently by the caller rather than failing the sync.
    public func fetchDailyActivity(date: Date) async throws -> ActivityDay? {
        let data = try await transport.get(path: "/users/activities/\(PolarDateFormat.dateOnly(date))")
        guard !data.isEmpty else { return nil }
        return try decode(ActivityDay.self, from: data)
    }

    /// `GET /users/activities/samples/{date}`. Step samples (each timestamped) are
    /// down-sampled to minute buckets; the zone time-series + inactivity stamps
    /// pass through (HERC-025).
    public func fetchActivitySamples(date: Date) async throws -> ActivitySamples {
        let dateString = PolarDateFormat.dateOnly(date)
        let data = try await transport.get(path: "/users/activities/samples/\(dateString)")
        // No-sample day (empty `204`): return an empty set rather than failing decode.
        guard !data.isEmpty else {
            return ActivitySamples(date: dateString, steps: [], zones: [], inactivityStamps: [])
        }
        let dto = try decode(ActivitySamplesDTO.self, from: data)
        let parse = PolarDateParser.shared

        let rawSteps: [RawStepSample] = (dto.steps?.samples ?? []).compactMap { s in
            guard let t = s.timestamp, let minute = parse.date(from: t) else { return nil }
            return RawStepSample(minute: minute, steps: s.steps ?? 0)
        }
        let zones: [ActivityZoneSample] = (dto.activityZones?.samples ?? []).compactMap { z in
            guard let t = z.timestamp, let minute = parse.date(from: t) else { return nil }
            return ActivityZoneSample(minute: minute, zone: ActivityZoneKind(raw: z.zone ?? ""))
        }
        let stamps: [InactivityStamp] = (dto.inactivityStamps?.samples ?? []).compactMap { s in
            guard let t = s.stamp, let time = parse.date(from: t) else { return nil }
            return InactivityStamp(time: time)
        }

        return ActivitySamples(
            date: dto.date ?? dateString,
            steps: Downsampler.stepMinutes(rawSteps, interval: dto.intervalSeconds),
            zones: zones,
            inactivityStamps: stamps
        )
    }

    // MARK: - Decoding helpers

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder.polar().decode(T.self, from: data)
        } catch {
            throw AuthError.decoding("v3 \(T.self) decode failed")
        }
    }

    /// Decode an envelope and project its array; an empty body is a valid `[]`.
    private func decodeList<E: Decodable, T>(_ data: Data, _ project: (E) -> [T]) throws -> [T] {
        guard !data.isEmpty else { return [] }
        return project(try decode(E.self, from: data))
    }
}

// MARK: - Response envelopes (private to the client)

private struct SleepEnvelope: Decodable { let nights: [SleepNight] }
private struct SleepManifestEnvelope: Decodable { let available: [SleepAvailability] }
private struct RechargeEnvelope: Decodable { let recharges: [NightlyRecharge] }

/// `{ heart_rates: [{ date, heart_rate_samples: [{ heart_rate, sample_time }] }] }`
private struct ContinuousHeartRateEnvelope: Decodable {
    let heartRates: [Day]
    enum CodingKeys: String, CodingKey { case heartRates = "heart_rates" }

    struct Day: Decodable {
        let date: String
        let heartRateSamples: [RawSample]
        enum CodingKeys: String, CodingKey {
            case date
            case heartRateSamples = "heart_rate_samples"
        }
    }
    struct RawSample: Decodable {
        let heartRate: Int?
        let sampleTime: String?
        enum CodingKeys: String, CodingKey {
            case heartRate = "heart_rate"
            case sampleTime = "sample_time"
        }
    }
}

/// Wire shape of `GET /users/activities/samples/{date}` — flattened into the
/// public `ActivitySamples` after step down-sampling.
private struct ActivitySamplesDTO: Decodable {
    let date: String?
    let steps: StepBlock?
    let activityZones: SampleBlock<ZoneSample>?
    let inactivityStamps: SampleBlock<StampSample>?

    enum CodingKeys: String, CodingKey {
        case date
        case steps
        case activityZones = "activity_zones"
        case inactivityStamps = "inactivity_stamps"
    }

    struct StepBlock: Decodable {
        let intervalMs: Int?
        let totalSteps: Int?
        let samples: [StepSample]?
        enum CodingKeys: String, CodingKey {
            case intervalMs = "interval_ms"
            case totalSteps = "total_steps"
            case samples
        }
    }
    struct StepSample: Decodable { let steps: Int?; let timestamp: String? }
    struct SampleBlock<S: Decodable>: Decodable { let samples: [S]? }
    struct ZoneSample: Decodable { let timestamp: String?; let zone: String? }
    struct StampSample: Decodable { let stamp: String? }

    var intervalSeconds: TimeInterval {
        TimeInterval(steps?.intervalMs ?? 60_000) / 1_000
    }
}
