import Foundation

/// Display model for the **Sleep Detail** week view (the `Sleep Detail.dc.html`
/// design, "02 · WEEK VIEW"): a 7-night aggregate — sleep matrix, trend, weekly
/// consolidation, and averaged stage totals. Flat `Sendable, Equatable` value
/// type assembled by a `SleepDetailProviding` off the main actor; the RHYTHM/BOOST
/// overlays stay `nil` until the SleepWise (Track B) data is joined in.
public struct SleepWeekDetail: Sendable, Equatable {
    /// `"JUN 22–28"` style range label.
    public let rangeLabel: String
    public let avgScore: Int?
    /// Averaged stage totals in fixed REM/LIGHT/DEEP/AWAKE order (present nights).
    public let avgStages: [SleepStageBar]
    public let avgContinuity: Double?
    public let avgInterruptMinutes: Int
    /// Per-night stage bands for the SLEEP MATRIX, oldest→newest.
    public let matrix: [SleepMatrixNight]
    /// Per-night trend points (SLEEP score + optional BOOST overlay).
    public let trend: [TrendPoint]
    /// True when the window has no recorded night.
    public let isEmpty: Bool

    public init(
        rangeLabel: String, avgScore: Int?, avgStages: [SleepStageBar],
        avgContinuity: Double?, avgInterruptMinutes: Int,
        matrix: [SleepMatrixNight], trend: [TrendPoint], isEmpty: Bool
    ) {
        self.rangeLabel = rangeLabel
        self.avgScore = avgScore
        self.avgStages = avgStages
        self.avgContinuity = avgContinuity
        self.avgInterruptMinutes = avgInterruptMinutes
        self.matrix = matrix
        self.trend = trend
        self.isEmpty = isEmpty
    }

    /// The empty-window representation (no night in range).
    public static func empty(rangeLabel: String) -> SleepWeekDetail {
        SleepWeekDetail(
            rangeLabel: rangeLabel, avgScore: nil, avgStages: SleepStageBar.emptySet,
            avgContinuity: nil, avgInterruptMinutes: 0, matrix: [], trend: [], isEmpty: true
        )
    }
}

/// One night in the SLEEP MATRIX column strip.
public struct SleepMatrixNight: Sendable, Equatable, Identifiable {
    public let date: String
    /// Weekday abbreviation (`"MON"`).
    public let dayLabel: String
    /// Total asleep minutes (bar height reference).
    public let asleepMinutes: Int
    /// Stage totals in fixed REM/LIGHT/DEEP/AWAKE order.
    public let stages: [SleepStageBar]
    /// SleepWise BOOST overlay 0…10, `nil` until Track B data exists.
    public let boost: Double?

    public var id: String { date }

    public init(date: String, dayLabel: String, asleepMinutes: Int,
                stages: [SleepStageBar], boost: Double?) {
        self.date = date
        self.dayLabel = dayLabel
        self.asleepMinutes = asleepMinutes
        self.stages = stages
        self.boost = boost
    }
}

/// One point on the weekly TREND line (SLEEP score, optional BOOST overlay).
public struct TrendPoint: Sendable, Equatable, Identifiable {
    public let date: String
    public let dayLabel: String
    public let score: Int?
    /// SleepWise BOOST overlay 0…10, `nil` until Track B data exists.
    public let boost: Double?

    public var id: String { date }

    public init(date: String, dayLabel: String, score: Int?, boost: Double?) {
        self.date = date
        self.dayLabel = dayLabel
        self.score = score
        self.boost = boost
    }
}

public extension SleepWeekDetail {
    /// A representative week matching the design mock, for stubs/previews.
    static func sample(rangeLabel: String = "JUN 22–28") -> SleepWeekDetail {
        let labels = ["FRI", "SAT", "SUN", "MON", "TUE", "WED", "THU"]
        let scores = [62, 55, 71, 48, 66, 68, 41]
        let matrix = zip(labels, scores).enumerated().map { i, pair -> SleepMatrixNight in
            SleepMatrixNight(
                date: "2026-06-\(19 + i)", dayLabel: pair.0,
                asleepMinutes: 360 + pair.1,
                stages: [
                    SleepStageBar(stage: .rem, minutes: 70 + pair.1 / 2),
                    SleepStageBar(stage: .light, minutes: 200),
                    SleepStageBar(stage: .deep, minutes: 80),
                    SleepStageBar(stage: .wake, minutes: 20),
                ],
                boost: nil
            )
        }
        let trend = zip(labels, scores).enumerated().map { i, pair in
            TrendPoint(date: "2026-06-\(19 + i)", dayLabel: pair.0, score: pair.1, boost: nil)
        }
        return SleepWeekDetail(
            rangeLabel: rangeLabel, avgScore: 59,
            avgStages: [
                SleepStageBar(stage: .rem, minutes: 88),
                SleepStageBar(stage: .light, minutes: 205),
                SleepStageBar(stage: .deep, minutes: 82),
                SleepStageBar(stage: .wake, minutes: 18),
            ],
            avgContinuity: 1.9, avgInterruptMinutes: 18, matrix: matrix, trend: trend, isEmpty: false
        )
    }
}
