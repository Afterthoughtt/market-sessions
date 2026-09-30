import Foundation

/// TradingView's market statuses minus Overnight, which no bundled market has.
/// A lunch recess or CME's maintenance hour is Closed, as TradingView has no pause status.
enum SessionStatus: String, CaseIterable, Hashable, Sendable {
    case open = "Open"
    case preMarket = "Pre-Market"
    case postMarket = "After Hours"
    case holiday = "Holiday"
    case closed = "Closed"

    var isActive: Bool { self == .open }

    var label: String { rawValue }
}

struct ResolvedSession: Identifiable, Hashable, Sendable {
    let session: MarketSession
    let status: SessionStatus
    /// Occurrence containing now, of any kind.
    let currentOccurrence: SessionOccurrence?
    /// Start of the contiguous active run containing now (the open, or the reopen after
    /// a recess); nil unless Open.
    let activeStart: Date?
    /// Start of the next active occurrence after now.
    let nextActiveStart: Date?
    let transition: SessionTransition?

    var id: MarketSession.ID { session.id }
}
