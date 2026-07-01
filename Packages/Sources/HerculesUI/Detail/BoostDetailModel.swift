import Foundation
import Observation
import PolarProtocol

/// View-model for the Boost From Sleep screen. Mirrors `SleepDetailModel`:
/// `@MainActor @Observable`, provider injected (stub default), state `private(set)`,
/// day list most-recent-first with an `index` (0 = newest). Local-first — reads
/// return instantly; no spinner (Norm 4). `detail` is non-optional: the empty /
/// calibrating cases are carried in `BoostDetail.state`.
@MainActor
@Observable
public final class BoostDetailModel {

    public private(set) var detail: BoostDetail = .placeholder

    private var days: [String] = []
    private var index = 0

    private let provider: any BoostDetailProviding

    public init(provider: any BoostDetailProviding = StubBoostDetailProvider()) {
        self.provider = provider
    }

    public var canShowOlder: Bool { index < days.count - 1 }
    public var canShowNewer: Bool { index > 0 }

    /// Load the night list and show the most recent night.
    public func load() async {
        days = await provider.availableDays()
        index = 0
        await refresh()
    }

    public func showOlder() async {
        guard canShowOlder else { return }
        index += 1
        await refresh()
    }

    public func showNewer() async {
        guard canShowNewer else { return }
        index -= 1
        await refresh()
    }

    private func refresh() async {
        guard days.indices.contains(index) else {
            detail = .noData(title: "TODAY", dateLabel: "")
            return
        }
        detail = await provider.detail(for: days[index])
    }
}
