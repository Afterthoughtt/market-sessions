import XCTest
@testable import MarketSessions

final class FocusSessionResolverTests: XCTestCase {
    // Menu bar: the nearest transition is London's 8:30 AM PDT close, so the outline
    // traces the time left.
    func testMenuBarTracesTheNearestClose() throws {
        let now = try makeDate(year: 2026, month: 8, day: 28, hour: 7, minute: 12)
        let resolved = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
        let next = try XCTUnwrap(
            resolved.min { ($0.transition?.date ?? .distantFuture) < ($1.transition?.date ?? .distantFuture) }
        )

        XCTAssertEqual(next.id, .london)
        XCTAssertNotNil(MenuBarLabel.traceRemaining(for: next, now: now))
    }

    // London's 8:00–16:30 run (0:00–8:30 AM PDT) in 60 steps of 8.5 minutes, rounded up
    // so the trace never empties before the close.
    func testMenuBarTraceStepsThroughTheOpenRun() throws {
        let now = try makeDate(year: 2026, month: 8, day: 28, hour: 7, minute: 12)
        let open = try makeDate(year: 2026, month: 8, day: 28, hour: 0, minute: 0)
        let close = try makeDate(year: 2026, month: 8, day: 28, hour: 8, minute: 30)
        let london = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
            .first { $0.id == .london }
        let next = try XCTUnwrap(london)

        XCTAssertEqual(next.activeStart, open)
        XCTAssertEqual(MenuBarLabel.traceRemaining(for: next, now: open), 1)
        // 78 of 510 minutes left: 9.2 steps, shown as 10.
        XCTAssertEqual(MenuBarLabel.traceRemaining(for: next, now: now), 10.0 / 60)
        XCTAssertEqual(MenuBarLabel.nextTraceStep(for: next, now: now), close.addingTimeInterval(-9 * 8.5 * 60))
        // The final step lasts until the close, which is already a wake-up.
        let lastMinute = close.addingTimeInterval(-30)
        XCTAssertEqual(MenuBarLabel.traceRemaining(for: next, now: lastMinute), 1.0 / 60)
        XCTAssertNil(MenuBarLabel.nextTraceStep(for: next, now: lastMinute))
    }

    // Saturday: nothing trading, so the whole outline while counting to CME's Sunday open.
    func testMenuBarShowsWholeOutlineWhileCountingToAnOpen() throws {
        let now = try makeDate(year: 2026, month: 8, day: 29, hour: 11, minute: 40)
        let resolved = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
        let next = try XCTUnwrap(
            resolved.min { ($0.transition?.date ?? .distantFuture) < ($1.transition?.date ?? .distantFuture) }
        )

        XCTAssertEqual(next.id, .cmeFutures)
        XCTAssertNil(next.activeStart)
        XCTAssertNil(MenuBarLabel.traceRemaining(for: next, now: now))
        XCTAssertNil(MenuBarLabel.nextTraceStep(for: next, now: now))
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZoneIdentifier: String = "America/Los_Angeles"
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = try XCTUnwrap(TimeZone(identifier: timeZoneIdentifier))
        calendar.timeZone = timeZone
        let components = DateComponents(
            timeZone: timeZone, year: year, month: month, day: day, hour: hour, minute: minute
        )
        return try XCTUnwrap(calendar.date(from: components))
    }
}
