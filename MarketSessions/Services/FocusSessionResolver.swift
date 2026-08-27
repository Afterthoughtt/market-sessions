import Foundation

/// Everything the open-now grid and the menu-bar label need, computed once per refresh.
struct FocusSnapshot: Hashable, Sendable {
    /// A currently open (or auction) session.
    struct OpenEntry: Hashable, Sendable {
        let sessionID: MarketSession.ID
        let code: String
        let name: String
        let status: SessionStatus
        let transition: SessionTransition
        /// Fraction of the trading day remaining (first open → final close, spanning
        /// recesses) — every ring is full at the day's open and drains to empty at
        /// the final close.
        let remainingFraction: Double
        /// Fraction of the trading day elapsed.
        let elapsedFraction: Double
        let remainingMinutes: Int
    }

    /// The next session to open, among sessions not currently trading.
    struct NextEntry: Hashable, Sendable {
        let sessionID: MarketSession.ID
        let code: String
        let name: String
        let opensAt: Date
        let approximate: Bool
        /// Fraction of the closed gap elapsed — fills toward the open.
        let fillFraction: Double
        let remainingMinutes: Int
    }

    /// Hero first (lowest focus priority), then remaining open sessions by nearest transition.
    let openEntries: [OpenEntry]
    let nextToOpen: NextEntry?

    var hero: OpenEntry? { openEntries.first }
    var secondary: [OpenEntry] { Array(openEntries.dropFirst()) }
}

struct FocusSessionResolver: Sendable {
    func resolve(_ sessions: [ResolvedSession], at now: Date) -> FocusSnapshot {
        let open = sessions.filter(\.status.isActive)

        var entries: [FocusSnapshot.OpenEntry] = open.compactMap { resolved in
            guard let transition = resolved.transition,
                  let cycleStart = resolved.activeCycleStart,
                  let cycleEnd = resolved.activeCycleEnd else {
                return nil
            }
            let elapsed = Self.clampedProgress(now: now, start: cycleStart, end: cycleEnd)
            return FocusSnapshot.OpenEntry(
                sessionID: resolved.session.id,
                code: resolved.session.code,
                name: resolved.session.name,
                status: resolved.status,
                transition: transition,
                remainingFraction: 1 - elapsed,
                elapsedFraction: elapsed,
                remainingMinutes: Self.remainingMinutes(until: transition.date, from: now)
            )
        }

        entries.sort { $0.transition.date < $1.transition.date }
        if let heroIndex = entries.indices.min(by: { lhs, rhs in
            MarketScheduleCatalog.session(entries[lhs].sessionID).focusPriority
                < MarketScheduleCatalog.session(entries[rhs].sessionID).focusPriority
        }), heroIndex != 0 {
            entries.insert(entries.remove(at: heroIndex), at: 0)
        }

        let upcoming = sessions
            .filter { !$0.status.isActive }
            .compactMap { resolved -> (ResolvedSession, Date)? in
                guard let next = resolved.nextActiveStart else { return nil }
                return (resolved, next)
            }
            .min { $0.1 < $1.1 }

        let nextToOpen = upcoming.map { resolved, opensAt in
            FocusSnapshot.NextEntry(
                sessionID: resolved.session.id,
                code: resolved.session.code,
                name: resolved.session.name,
                opensAt: opensAt,
                approximate: resolved.session.approximateTimes,
                fillFraction: Self.clampedProgress(
                    now: now,
                    start: resolved.previousActiveEnd,
                    end: opensAt
                ),
                remainingMinutes: Self.remainingMinutes(until: opensAt, from: now)
            )
        }

        return FocusSnapshot(openEntries: entries, nextToOpen: nextToOpen)
    }

    static func clampedProgress(now: Date, start: Date?, end: Date?) -> Double {
        guard let start, let end else { return 0 }
        let duration = end.timeIntervalSince(start)
        guard duration > 0, duration.isFinite else { return 0 }
        let elapsed = now.timeIntervalSince(start)
        guard elapsed.isFinite else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    static func remainingMinutes(until date: Date, from now: Date) -> Int {
        max(0, Int(ceil(date.timeIntervalSince(now) / 60)))
    }
}
