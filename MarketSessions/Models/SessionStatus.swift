import Foundation

enum SessionStatus: Hashable, Sendable {
    case active(phase: String? = nil)
    case recess(String)
    case maintenance(String)
    case informational(String)
    case closed

    var isActive: Bool {
        if case .active = self {
            return true
        }
        return false
    }

    var label: String {
        switch self {
        case .active(let phase):
            phase ?? "Open"
        case .recess:
            "Recess"
        case .maintenance:
            "Maintenance"
        case .informational(let label):
            label
        case .closed:
            "Closed"
        }
    }
}

struct ResolvedSession: Identifiable, Hashable, Sendable {
    let session: MarketSession
    let status: SessionStatus
    let currentOccurrence: SessionOccurrence?
    let previousActiveOccurrence: SessionOccurrence?
    let nextActiveOccurrence: SessionOccurrence?
    let activeCycleOccurrences: [SessionOccurrence]
    let transition: SessionTransition?
    let todayIntervals: [SessionDisplayInterval]

    var id: MarketSession.ID { session.id }
}
