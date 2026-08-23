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
        let currentActive = activeOccurrences.first(where: { $0.contains(now) })
        let currentInactive = occurrences.first(where: { !$0.kind.countsAsActive && $0.contains(now) })
        let previousActive = activeOccurrences.last(where: { $0.end <= now })
        let nextActive = activeOccurrences.first(where: { $0.start >= now })

        let status: SessionStatus
        let currentOccurrence: SessionOccurrence?
        let transition: SessionTransition?

        if let currentActive {
            currentOccurrence = currentActive
            if case .trading(let phase) = currentActive.kind {
                status = .active(phase: phase)
            } else {
                status = .active()
            }
            transition = SessionTransition(kind: .closes, date: currentActive.end)
        } else if let currentInactive {
            currentOccurrence = currentInactive
            switch currentInactive.kind {
            case .recess(let label):
                status = .recess(label)
                transition = SessionTransition(kind: .resumes, date: nextActive?.start ?? currentInactive.end)
            case .maintenance(let label):
                status = .maintenance(label)
                transition = SessionTransition(kind: .resumes, date: nextActive?.start ?? currentInactive.end)
            case .informational(let label):
                status = .informational(label)
                transition = SessionTransition(kind: .phaseEnds, date: currentInactive.end)
            case .trading:
                status = .closed
                transition = nextActive.map { SessionTransition(kind: .opens, date: $0.start) }
            }
        } else {
            currentOccurrence = nil
            status = .closed
            transition = nextActive.map { SessionTransition(kind: .opens, date: $0.start) }
        }

        let activeCycleOccurrences: [SessionOccurrence]
        if let currentActive {
            activeCycleOccurrences = activeOccurrences.filter { $0.anchorDate == currentActive.anchorDate }
        } else {
            activeCycleOccurrences = []
        }

        return ResolvedSession(
            session: session,
            status: status,
            currentOccurrence: currentOccurrence,
            previousActiveOccurrence: previousActive,
            nextActiveOccurrence: nextActive,
            activeCycleOccurrences: activeCycleOccurrences,
            transition: transition,
            todayIntervals: displayIntervals(from: occurrences, at: now)
        )
    }

    func resolve(_ sessions: [MarketSession], at now: Date) -> [ResolvedSession] {
        sessions.map { resolve($0, at: now) }
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

    private func displayIntervals(
        from occurrences: [SessionOccurrence],
        at now: Date
    ) -> [SessionDisplayInterval] {
        var calendar = baseCalendar
        calendar.timeZone = displayTimeZone
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return occurrences.compactMap { occurrence in
            let start = max(occurrence.start, dayStart)
            let end = min(occurrence.end, dayEnd)
            guard end > start else { return nil }
            return SessionDisplayInterval(kind: occurrence.kind, start: start, end: end)
        }
        .sorted { $0.start < $1.start }
    }
}
