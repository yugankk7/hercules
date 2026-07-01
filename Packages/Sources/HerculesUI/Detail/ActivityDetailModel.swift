import Foundation
import Observation
import PolarProtocol

/// View-model for the Daily Activity detail screen. Mirrors `DashboardModel`:
/// `@MainActor @Observable`, provider injected (stub default), state `private(set)`.
/// Local-first — reads return instantly from the store; no spinner. Holds the list of
/// stored days (most-recent first) so the screen can swipe between them.
@MainActor
@Observable
public final class ActivityDetailModel {

    public private(set) var detail: ActivityDetail?

    /// Available days, most-recent first, and the currently-shown index.
    private var days: [String] = []
    private var index = 0

    private let provider: any ActivityDetailProviding

    public init(provider: any ActivityDetailProviding = StubActivityDetailProvider()) {
        self.provider = provider
    }

    /// True when an older / newer day exists to swipe to (index 0 = most recent).
    public var canShowOlder: Bool { index < days.count - 1 }
    public var canShowNewer: Bool { index > 0 }

    /// Load the day list and show the most recent day.
    public func load() async {
        days = await provider.availableDays()
        index = 0
        await refreshDetail()
    }

    /// Step one day back in time (older).
    public func showOlder() async {
        guard canShowOlder else { return }
        index += 1
        await refreshDetail()
    }

    /// Step one day forward in time (newer).
    public func showNewer() async {
        guard canShowNewer else { return }
        index -= 1
        await refreshDetail()
    }

    private func refreshDetail() async {
        guard days.indices.contains(index) else { detail = nil; return }
        detail = await provider.detail(for: days[index])
    }
}
