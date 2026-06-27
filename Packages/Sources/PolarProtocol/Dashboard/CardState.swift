import Foundation

/// The render state of a dashboard card. This slice only ever emits `.empty`;
/// the remaining cases exist so future populated cards and their states need no
/// enum change (Extensibility, Safeguard 9). Absence of data is a first-class
/// state here — never an error (Norm 5).
public enum CardState: Sendable, Equatable {
    case populated
    case empty
    case noData
    case stale
    case calibrating
}
