import XCTest
@testable import MarketSessions

final class FocusSessionResolverTests: XCTestCase {
    func testRealOverlapUsesNewYorkCashPriority() throws {
        let now = try makeDate(
            year: 2026, month: 8, day: 24, hour: 10, minute: 0,
            timeZoneIdentifier: "America/New_York"
        )
        let rows = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
        let focus = FocusSessionResolver().resolve(rows, at: now)

        XCTAssertEqual(focus?.sessionID, .newYorkCash)
        XCTAssertEqual(focus?.mode, .active)
    }

    func testEveryActivePriorityTieUsesTheHighestRemainingPriority() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let ordered = MarketScheduleCatalog.sessions
            .filter { $0.focusPriority != nil }
            .sorted { $0.focusPriority! < $1.focusPriority! }

        for index in ordered.indices {
            let remaining = ordered[index...].reversed().map { activeRow(for: $0, now: now) }
            let focus = FocusSessionResolver().resolve(remaining, at: now)
            XCTAssertEqual(focus?.sessionID, ordered[index].id)
        }
    }

    func testEarliestUpcomingOpenWinsBeforePriority() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let highPriority = closedRow(
            for: MarketScheduleCatalog.session(.newYorkCash),
            now: now,
            nextOpen: now.addingTimeInterval(3_600)
        )
        let lowerPriority = closedRow(
            for: MarketScheduleCatalog.session(.tokyo),
            now: now,
            nextOpen: now.addingTimeInterval(1_800)
        )

        let focus = FocusSessionResolver().resolve([highPriority, lowerPriority], at: now)

        XCTAssertEqual(focus?.sessionID, .tokyo)
        XCTAssertEqual(focus?.mode, .upcoming)
        XCTAssertEqual(focus?.remainingMinutes, 30)
    }

    func testPriorityBreaksAnUpcomingOpenTie() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sameOpen = now.addingTimeInterval(3_600)
        let london = closedRow(
            for: MarketScheduleCatalog.session(.london),
            now: now,
            nextOpen: sameOpen
        )
        let cash = closedRow(
            for: MarketScheduleCatalog.session(.newYorkCash),
            now: now,
            nextOpen: sameOpen
        )

        XCTAssertEqual(FocusSessionResolver().resolve([london, cash], at: now)?.sessionID, .newYorkCash)
    }

    func testSpotFXIsExcludedAndCryptoIsFallback() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let spot = activeRow(for: MarketScheduleCatalog.session(.spotFX), now: now)
        let crypto = activeRow(for: MarketScheduleCatalog.session(.cryptoUTC), now: now)

        let focus = FocusSessionResolver().resolve([spot, crypto], at: now)

        XCTAssertEqual(focus?.sessionID, .cryptoUTC)
        XCTAssertEqual(focus?.mode, .fallback)
    }

    func testExactBoundaryProducesNewFocusStateWithoutZeroMinuteStaleState() throws {
        let boundary = try makeDate(
            year: 2026, month: 8, day: 24, hour: 16, minute: 0,
            timeZoneIdentifier: "America/New_York"
        )
        let rows = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: boundary)
        let focus = try XCTUnwrap(FocusSessionResolver().resolve(rows, at: boundary))

        XCTAssertNotEqual(focus.sessionID, .newYorkCash)
        XCTAssertGreaterThan(focus.remainingMinutes, 0)
    }

    func testCountdownFormattingUsesMinutesHoursAndDays() {
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: -1), "0m")
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 0), "0m")
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 59), "59m")
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 60), "1h")
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 61), "1h 1m")
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 1_376), "22h 56m")
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 1_440), "1d")
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 3_074), "2d 3h 14m")
        XCTAssertEqual(
            MarketDurationFormatting.spoken(minutes: 1_501),
            "1 day, 1 hour, 1 minute"
        )
    }

    private func activeRow(for session: MarketSession, now: Date) -> ResolvedSession {
        let occurrence = SessionOccurrence(
            sessionID: session.id,
            kind: .trading(),
            start: now.addingTimeInterval(-1_800),
            end: now.addingTimeInterval(1_800),
            anchorDate: now.addingTimeInterval(-1_800)
        )
        return ResolvedSession(
            session: session,
            status: .active(),
            currentOccurrence: occurrence,
            previousActiveOccurrence: nil,
            nextActiveOccurrence: nil,
            activeCycleOccurrences: [occurrence],
            transition: SessionTransition(kind: .closes, date: occurrence.end),
            todayIntervals: []
        )
    }

    private func closedRow(for session: MarketSession, now: Date, nextOpen: Date) -> ResolvedSession {
        let previous = SessionOccurrence(
            sessionID: session.id,
            kind: .trading(),
            start: now.addingTimeInterval(-7_200),
            end: now.addingTimeInterval(-3_600),
            anchorDate: now.addingTimeInterval(-7_200)
        )
        let next = SessionOccurrence(
            sessionID: session.id,
            kind: .trading(),
            start: nextOpen,
            end: nextOpen.addingTimeInterval(3_600),
            anchorDate: nextOpen
        )
        return ResolvedSession(
            session: session,
            status: .closed,
            currentOccurrence: nil,
            previousActiveOccurrence: previous,
            nextActiveOccurrence: next,
            activeCycleOccurrences: [],
            transition: SessionTransition(kind: .opens, date: nextOpen),
            todayIntervals: []
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZoneIdentifier: String
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: timeZoneIdentifier))
        return try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}
