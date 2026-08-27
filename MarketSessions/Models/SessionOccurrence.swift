import Foundation

struct SessionOccurrence: Hashable, Sendable {
    let sessionID: MarketSession.ID
    let kind: SessionIntervalKind
    let start: Date
    let end: Date
    let anchorDate: Date

    var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }

    func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }
}

struct SessionTransition: Hashable, Sendable {
    enum Verb: String, Hashable, Sendable {
        case opens = "Opens"
        case closes = "Closes"
        case resumes = "Resumes"
        case reopens = "Reopens"
    }

    let verb: Verb
    let date: Date
    /// True for CME — rendered with a `≈` prefix on the time.
    let approximate: Bool
}
