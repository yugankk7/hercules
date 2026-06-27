import Foundation

/// The linear onboarding progression, mapped 1:1 to the design frames
/// (Welcome → Consent → Secure hand-off → Authorizing → Initial sync → Done).
public enum OnboardingStep: Sendable, Equatable {
    case welcome
    case consent
    case handoff
    case authorizing
    case syncing
    case done
}
