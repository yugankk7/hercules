import Foundation

/// Drives the onboarding Initial-sync screen. The real sync engine lands in
/// EPIC 5; today a stub animates synthetic progress so the visual flow is complete.
public protocol InitialSyncProviding: Sendable {
    /// Run the initial sync, reporting fractional progress (0→1).
    func run(progress: @escaping @Sendable (Double) -> Void) async throws
}

/// Emits synthetic progress 0→1 over a short interval so the Initial-sync screen
/// animates. Replaced by the real engine in EPIC 5.
public struct StubInitialSyncProvider: InitialSyncProviding {
    private let steps: Int
    private let stepDelay: Duration

    public init(steps: Int = 40, stepDelay: Duration = .milliseconds(65)) {
        self.steps = steps
        self.stepDelay = stepDelay
    }

    public func run(progress: @escaping @Sendable (Double) -> Void) async throws {
        progress(0)
        for i in 1...steps {
            try await Task.sleep(for: stepDelay)
            progress(Double(i) / Double(steps))
        }
    }
}
