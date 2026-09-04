import Foundation

enum SessionStatus: String, CaseIterable, Hashable, Sendable {
    case open = "Open"
    case onBreak = "Break"
    case closed = "Closed"

    var isActive: Bool { self == .open }

    var label: String { rawValue }
}

struct ResolvedSession: Identifiable, Hashable, Sendable {
    let session: MarketSession
    let status: SessionStatus
    /// Occurrence containing now, of any kind.
    let currentOccurrence: SessionOccurrence?
    /// Start of the uninterrupted trading period ending at the displayed close.
    let activePeriodStart: Date?
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

    /// Full at open, empty at the next close. Adjacent auctions remain in the
    /// same period; a lunch recess or maintenance break starts a new period.
    func remainingTradingFraction(at now: Date) -> Double {
        guard status.isActive, let start = activePeriodStart,
              let end = transition?.date, end > start else { return 0 }
        return 1 - FocusSessionResolver.clampedProgress(now: now, start: start, end: end)
    }
}
