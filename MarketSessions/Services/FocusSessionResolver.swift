import Foundation

enum FocusMode: Hashable, Sendable {
    case active
    case upcoming
    case fallback
}

struct FocusSession: Hashable, Sendable {
    let sessionID: MarketSession.ID
    let sessionName: String
    let iconName: String
    let mode: FocusMode
    let statusLabel: String
    let actionLabel: String
    let transitionDate: Date
    let remainingMinutes: Int
    let progress: Double

    var countdownText: String {
        MarketDurationFormatting.compact(minutes: remainingMinutes)
    }

    var accessibilityCountdownText: String {
        MarketDurationFormatting.spoken(minutes: remainingMinutes)
    }
}

struct FocusSessionResolver: Sendable {
    func resolve(_ sessions: [ResolvedSession], at now: Date) -> FocusSession? {
        let eligible = sessions.filter { $0.session.focusPriority != nil }
        let active = eligible
            .filter(\.status.isActive)
            .sorted(by: priorityOrder)

        if let selected = active.first,
           let occurrence = selected.currentOccurrence {
            return makeActiveFocus(from: selected, occurrence: occurrence, at: now, mode: .active)
        }

        let upcoming = eligible
            .compactMap { resolved -> (ResolvedSession, SessionOccurrence)? in
                guard let occurrence = resolved.nextActiveOccurrence else { return nil }
                return (resolved, occurrence)
            }
            .sorted { lhs, rhs in
                if lhs.1.start == rhs.1.start {
                    return priorityOrder(lhs.0, rhs.0)
                }
                return lhs.1.start < rhs.1.start
            }

        if let (selected, occurrence) = upcoming.first {
            let progress = Self.clampedProgress(
                now: now,
                start: selected.previousActiveOccurrence?.end,
                end: occurrence.start
            )
            return FocusSession(
                sessionID: selected.session.id,
                sessionName: selected.session.shortName,
                iconName: selected.session.iconName,
                mode: .upcoming,
                statusLabel: "Closed",
                actionLabel: "Opens in",
                transitionDate: occurrence.start,
                remainingMinutes: remainingMinutes(until: occurrence.start, from: now),
                progress: progress
            )
        }

        guard let crypto = sessions.first(where: { $0.session.id == .cryptoUTC }),
              let occurrence = crypto.currentOccurrence else {
            return nil
        }
        return makeActiveFocus(from: crypto, occurrence: occurrence, at: now, mode: .fallback)
    }

    static func clampedProgress(now: Date, start: Date?, end: Date?) -> Double {
        guard let start, let end else { return 0 }
        let duration = end.timeIntervalSince(start)
        guard duration > 0, duration.isFinite else { return 0 }
        let elapsed = now.timeIntervalSince(start)
        guard elapsed.isFinite else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    private func makeActiveFocus(
        from resolved: ResolvedSession,
        occurrence: SessionOccurrence,
        at now: Date,
        mode: FocusMode
    ) -> FocusSession {
        let cycle = resolved.activeCycleOccurrences.isEmpty
            ? [occurrence]
            : resolved.activeCycleOccurrences
        let total = cycle.reduce(0) { $0 + $1.duration }
        let completed = cycle.reduce(0) { partial, item in
            let elapsed = min(max(now.timeIntervalSince(item.start), 0), item.duration)
            return partial + elapsed
        }
        let progress = total > 0 && total.isFinite
            ? min(max(completed / total, 0), 1)
            : 0
        let actionLabel = mode == .fallback ? "UTC day ends in" : "Closes in"

        return FocusSession(
            sessionID: resolved.session.id,
            sessionName: resolved.session.shortName,
            iconName: resolved.session.iconName,
            mode: mode,
            statusLabel: resolved.status.label,
            actionLabel: actionLabel,
            transitionDate: occurrence.end,
            remainingMinutes: remainingMinutes(until: occurrence.end, from: now),
            progress: progress
        )
    }

    private func priorityOrder(_ lhs: ResolvedSession, _ rhs: ResolvedSession) -> Bool {
        (lhs.session.focusPriority ?? .max) < (rhs.session.focusPriority ?? .max)
    }

    private func remainingMinutes(until date: Date, from now: Date) -> Int {
        max(0, Int(ceil(date.timeIntervalSince(now) / 60)))
    }
}
