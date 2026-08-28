import Foundation

enum SessionStatus: String, Hashable, Sendable {
    case open = "Open"
    case auction = "Auction"
    case recess = "Recess"
    case maintenance = "Maintenance"
    case preMarket = "Pre-market"
    case postMarket = "Post-market"
    case closed = "Closed"

    /// "Can you trade" — open and auction count.
    var isActive: Bool {
        self == .open || self == .auction
    }

    var label: String { rawValue }
}

struct ResolvedSession: Identifiable, Hashable, Sendable {
    let session: MarketSession
    let status: SessionStatus
    /// Occurrence containing now, of any kind.
    let currentOccurrence: SessionOccurrence?
    /// First open of the current trading day (the whole cycle, spanning recesses).
    let activeCycleStart: Date?
    /// Final close of the current trading day.
    let activeCycleEnd: Date?
    /// End of the most recent active occurrence at or before now.
    let previousActiveEnd: Date?
    /// Start of the next active occurrence after now.
    let nextActiveStart: Date?
    let transition: SessionTransition?

    var id: MarketSession.ID { session.id }
}
