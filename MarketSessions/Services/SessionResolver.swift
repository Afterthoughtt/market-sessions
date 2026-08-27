import Foundation

struct SessionResolver: Sendable {
    private let baseCalendar: Calendar
    let displayTimeZone: TimeZone

    init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        displayTimeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.baseCalendar = calendar
        self.displayTimeZone = displayTimeZone
    }

    func resolve(_ session: MarketSession, at now: Date) -> ResolvedSession {
        let occurrences = occurrences(for: session, around: now)
        let activeOccurrences = occurrences.filter(\.kind.countsAsActive)
        let current = occurrences.first(where: { $0.contains(now) && $0.kind.countsAsActive })
            ?? occurrences.first(where: { $0.contains(now) })
        let previousActiveEnd = activeOccurrences.last(where: { $0.end <= now })?.end
        let nextActiveStart = activeOccurrences.first(where: { $0.start > now })?.start
        let approximate = session.approximateTimes

        let status: SessionStatus
        var chainStart: Date?
        var chainEnd: Date?
        var cycleStart: Date?
        var cycleEnd: Date?
        let transition: SessionTransition?

        if let current, current.kind.countsAsActive {
            status = current.kind == .auction ? .auction : .open
            let chain = activeChain(containing: current, in: activeOccurrences)
            chainStart = chain.first?.start
            chainEnd = chain.last?.end
            let cycle = activeOccurrences.filter { $0.anchorDate == current.anchorDate }
            cycleStart = cycle.first?.start
            cycleEnd = cycle.last?.end
            transition = SessionTransition(verb: .closes, date: chainEnd ?? current.end, approximate: approximate)
        } else if let current {
            switch current.kind {
            case .recess:
                status = .recess
                transition = SessionTransition(
                    verb: .resumes,
                    date: nextActiveStart ?? current.end,
                    approximate: approximate
                )
            case .maintenance:
                status = .maintenance
                transition = SessionTransition(
                    verb: .reopens,
                    date: nextActiveStart ?? current.end,
                    approximate: approximate
                )
            case .preMarket:
                status = .preMarket
                transition = SessionTransition(
                    verb: .opens,
                    date: nextActiveStart ?? current.end,
                    approximate: approximate
                )
            case .postMarket:
                status = .postMarket
                transition = nextActiveStart.map {
                    SessionTransition(verb: .opens, date: $0, approximate: approximate)
                }
            case .trading, .auction:
                status = .closed
                transition = nextActiveStart.map {
                    SessionTransition(verb: .opens, date: $0, approximate: approximate)
                }
            }
        } else {
            status = .closed
            transition = nextActiveStart.map {
                SessionTransition(verb: .opens, date: $0, approximate: approximate)
            }
        }

        return ResolvedSession(
            session: session,
            status: status,
            currentOccurrence: current,
            activeChainStart: chainStart,
            activeChainEnd: chainEnd,
            activeCycleStart: cycleStart,
            activeCycleEnd: cycleEnd,
            previousActiveEnd: previousActiveEnd,
            nextActiveStart: nextActiveStart,
            transition: transition
        )
    }

    func resolve(_ sessions: [MarketSession], at now: Date) -> [ResolvedSession] {
        sessions.map { resolve($0, at: now) }
    }

    /// Contiguous run of active occurrences (trading + adjacent auction) containing `occurrence`.
    private func activeChain(
        containing occurrence: SessionOccurrence,
        in activeOccurrences: [SessionOccurrence]
    ) -> [SessionOccurrence] {
        guard let index = activeOccurrences.firstIndex(of: occurrence) else { return [occurrence] }
        var startIndex = index
        while startIndex > 0, activeOccurrences[startIndex - 1].end == activeOccurrences[startIndex].start {
            startIndex -= 1
        }
        var endIndex = index
        while endIndex + 1 < activeOccurrences.count,
              activeOccurrences[endIndex + 1].start == activeOccurrences[endIndex].end {
            endIndex += 1
        }
        return Array(activeOccurrences[startIndex...endIndex])
    }

    func occurrences(for session: MarketSession, around now: Date) -> [SessionOccurrence] {
        var calendar = baseCalendar
        calendar.timeZone = session.canonicalTimeZone
        let canonicalToday = calendar.startOfDay(for: now)
        var result: [SessionOccurrence] = []

        for dayOffset in -10...14 {
            guard let anchorDate = calendar.date(byAdding: .day, value: dayOffset, to: canonicalToday),
                  let weekday = Weekday(rawValue: calendar.component(.weekday, from: anchorDate)) else {
                continue
            }

            for interval in session.intervals where interval.weekdays.contains(weekday) {
                guard let start = date(on: anchorDate, at: interval.start, calendar: calendar),
                      let endAnchor = calendar.date(
                        byAdding: .day,
                        value: interval.endDayOffset,
                        to: anchorDate
                      ),
                      let end = date(on: endAnchor, at: interval.end, calendar: calendar),
                      end > start else {
                    continue
                }

                result.append(
                    SessionOccurrence(
                        sessionID: session.id,
                        kind: interval.kind,
                        start: start,
                        end: end,
                        anchorDate: anchorDate
                    )
                )
            }
        }

        return result.sorted {
            if $0.start == $1.start {
                return $0.end < $1.end
            }
            return $0.start < $1.start
        }
    }

    private func date(on day: Date, at time: LocalTime, calendar: Calendar) -> Date? {
        let dayComponents = calendar.dateComponents([.era, .year, .month, .day], from: day)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.era = dayComponents.era
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components)
    }
}
