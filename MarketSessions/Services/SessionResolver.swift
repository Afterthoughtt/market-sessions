import Foundation

struct SessionResolver: Sendable {
    private let baseCalendar: Calendar
    private let exceptions: MarketExceptionIndex
    let displayTimeZone: TimeZone

    init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        displayTimeZone: TimeZone = .autoupdatingCurrent,
        exceptions: MarketExceptionIndex = .empty
    ) {
        self.baseCalendar = calendar
        self.displayTimeZone = displayTimeZone
        self.exceptions = exceptions
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
        var cycleStart: Date?
        var cycleEnd: Date?
        let transition: SessionTransition?

        if let current, current.kind.countsAsActive {
            status = current.kind == .auction ? .auction : .open
            let chain = activeChain(containing: current, in: activeOccurrences)
            let cycle = activeOccurrences.filter { $0.anchorDate == current.anchorDate }
            cycleStart = cycle.first?.start
            cycleEnd = cycle.last?.end
            transition = SessionTransition(
                verb: .closes,
                date: chain.last?.end ?? current.end,
                approximate: approximate
            )
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

                let occurrence = SessionOccurrence(
                    sessionID: session.id,
                    kind: interval.kind,
                    start: start,
                    end: end,
                    anchorDate: anchorDate
                )
                if let adjusted = applyingExceptions(to: occurrence, calendar: calendar) {
                    result.append(adjusted)
                }
            }
        }

        return result.sorted {
            if $0.start == $1.start {
                return $0.end < $1.end
            }
            return $0.start < $1.start
        }
    }

    /// Holiday: the occurrence vanishes if either its start or end falls on the
    /// holiday date. Early close: an occurrence straddling the close is clamped;
    /// one starting at/after the close and ending the same day (an afternoon
    /// session, an auction, maintenance) is dropped — but a re-open that runs into
    /// the next day (CME's evening session after a holiday early close) survives.
    private func applyingExceptions(
        to occurrence: SessionOccurrence,
        calendar: Calendar
    ) -> SessionOccurrence? {
        let startException = exceptions.exception(for: occurrence.sessionID, on: occurrence.start, calendar: calendar)
        let endException = exceptions.exception(for: occurrence.sessionID, on: occurrence.end, calendar: calendar)

        if startException?.kind == .holiday || endException?.kind == .holiday {
            return nil
        }

        for exception in [startException, endException] {
            guard let exception, exception.kind == .earlyClose, let close = exception.close else { continue }
            var closeComponents = DateComponents()
            closeComponents.year = exception.year
            closeComponents.month = exception.month
            closeComponents.day = exception.day
            closeComponents.hour = close.hour
            closeComponents.minute = close.minute
            guard let closeDate = calendar.date(from: closeComponents) else { continue }

            if occurrence.start < closeDate, occurrence.end > closeDate {
                return SessionOccurrence(
                    sessionID: occurrence.sessionID,
                    kind: occurrence.kind,
                    start: occurrence.start,
                    end: closeDate,
                    anchorDate: occurrence.anchorDate
                )
            }
            if occurrence.start >= closeDate,
               MarketExceptionIndex.key(for: occurrence.end, calendar: calendar) == exception.dateKey {
                return nil
            }
        }
        return occurrence
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
