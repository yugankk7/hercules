import Foundation
import Observation
import PolarProtocol

/// View-model for the Sleep Detail screen. Mirrors `ActivityDetailModel`:
/// `@MainActor @Observable`, provider injected (stub default), state `private(set)`,
/// day list held most-recent-first with an `index` (index 0 = newest). Local-first —
/// reads return instantly from the store; no spinner (Norm 4). Adds a DAY/WK `mode`
/// and a `week` aggregate alongside the per-day `detail`.
@MainActor
@Observable
public final class SleepDetailModel {

    /// DAY / WK toggle mirroring the design's mode switch.
    public enum Mode: Sendable { case day, week }

    public private(set) var detail: SleepDetail?
    public private(set) var week: SleepWeekDetail?
    public private(set) var mode: Mode = .day

    private var days: [String] = []
    private var index = 0

    private let provider: any SleepDetailProviding

    public init(provider: any SleepDetailProviding = StubSleepDetailProvider()) {
        self.provider = provider
    }

    /// True when an older / newer night exists to swipe to (index 0 = most recent).
    public var canShowOlder: Bool { index < days.count - 1 }
    public var canShowNewer: Bool { index > 0 }

    /// Load the night list and show the most recent night (both day + week).
    public func load() async {
        days = await provider.availableDays()
        index = 0
        await refresh()
    }

    /// Step one night back in time (older).
    public func showOlder() async {
        guard canShowOlder else { return }
        index += 1
        await refresh()
    }

    /// Step one night forward in time (newer).
    public func showNewer() async {
        guard canShowNewer else { return }
        index -= 1
        await refresh()
    }

    /// Toggle the DAY/WK subview.
    public func setMode(_ mode: Mode) {
        self.mode = mode
    }

    private func refresh() async {
        guard days.indices.contains(index) else { detail = nil; week = nil; return }
        detail = await provider.detail(for: days[index])
        week = await provider.week(endingAt: days[index])
    }
}
