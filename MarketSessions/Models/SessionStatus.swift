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
    /// The close shown is a bundled early close, so the row says ", early".
    var closesEarly = false

    var id: MarketSession.ID { session.id }

    /// Empty at the open, full at the close shown, filling like a determinate progress
    /// bar (HIG Progress indicators); 0 unless Open.
    func elapsedFraction(at now: Date) -> Double {
        guard let start = activeStart, let end = transition?.date, end > start else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }
}
