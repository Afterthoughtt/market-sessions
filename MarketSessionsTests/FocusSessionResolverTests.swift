import XCTest
@testable import MarketSessions

final class FocusSessionResolverTests: XCTestCase {
    func testClampedProgressBounds() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(
            FocusSessionResolver.clampedProgress(now: now, start: nil, end: now.addingTimeInterval(60)),
            0
        )
        XCTAssertEqual(
            FocusSessionResolver.clampedProgress(
                now: now,
                start: now.addingTimeInterval(-120),
                end: now.addingTimeInterval(-60)
            ),
            1
        )
        XCTAssertEqual(
            FocusSessionResolver.clampedProgress(
                now: now,
                start: now.addingTimeInterval(-60),
                end: now.addingTimeInterval(60)
            ),
            0.5,
            accuracy: 0.000_001
        )
    }

    // Menu bar: the nearest transition is London's 8:30 AM PDT close, so a filled pill,
    // and a countdown only inside the final 59 minutes.
    func testMenuBarCountsDownOnlyInTheFinalHour() throws {
        let now = try makeDate(year: 2026, month: 8, day: 28, hour: 7, minute: 12)
        let resolved = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
        let next = try XCTUnwrap(
            resolved.min { ($0.transition?.date ?? .distantFuture) < ($1.transition?.date ?? .distantFuture) }
        )

        XCTAssertEqual(next.id, .london)
        XCTAssertTrue(MenuBarLabel.isFilled(next))
        XCTAssertNil(MenuBarLabel.countdown(for: next, now: now))  // 1h 18m out
        XCTAssertEqual(MenuBarLabel.countdown(for: next, now: now.addingTimeInterval(19 * 60)), "59m")
        XCTAssertEqual(MenuBarLabel.countdown(for: next, now: now.addingTimeInterval(77 * 60 + 30)), "1m")
    }

    // Saturday: nothing trading, so an outlined pill; CME's Sunday open is too far off to count down.
    func testMenuBarShowsOutlinedPillWithoutCountdownWhileFarFromAnOpen() throws {
        let now = try makeDate(year: 2026, month: 8, day: 29, hour: 11, minute: 40)
        let resolved = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
        let next = try XCTUnwrap(
            resolved.min { ($0.transition?.date ?? .distantFuture) < ($1.transition?.date ?? .distantFuture) }
        )

        XCTAssertEqual(next.id, .cmeFutures)
        XCTAssertFalse(MenuBarLabel.isFilled(next))
        XCTAssertNil(MenuBarLabel.countdown(for: next, now: now))
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
