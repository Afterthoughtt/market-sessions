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
    }

    let verb: Verb
    let date: Date
}
