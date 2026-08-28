import XCTest
@testable import MarketSessions

final class FocusSessionResolverTests: XCTestCase {
    // The design moment: Friday 2026-08-28 7:12 AM PDT — NY, London, and CME open.
    func testDesignMomentHeroSecondaryAndNextToOpen() throws {
        let now = try makeDate(year: 2026, month: 8, day: 28, hour: 7, minute: 12)
        let resolved = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
        let focus = FocusSessionResolver().resolve(resolved, at: now)

        XCTAssertEqual(focus.openEntries.count, 3)
        XCTAssertEqual(focus.hero?.sessionID, .newYorkCash)
        // Secondary cells order by nearest close: London (8:30 AM) before CME (2:00 PM).
        XCTAssertEqual(focus.secondary.map(\.sessionID), [.london, .cmeFutures])

        let hero = try XCTUnwrap(focus.hero)
        XCTAssertEqual(hero.remainingMinutes, 348)
        XCTAssertEqual(hero.remainingFraction, 348.0 / 390.0, accuracy: 0.000_001)

        let london = try XCTUnwrap(focus.secondary.first)
        XCTAssertEqual(london.remainingMinutes, 78)

        // Tokyo is the next session to open: Monday 9:00 JST = Sunday 5:00 PM PDT.
        let next = try XCTUnwrap(focus.nextToOpen)
        XCTAssertEqual(next.sessionID, .tokyo)
        XCTAssertEqual(
            next.opensAt,
            try makeDate(year: 2026, month: 8, day: 30, hour: 17, minute: 0)
        )
    }

    // Saturday 2026-08-29 11:40 AM PDT — nothing trading; CME opens Sunday 3:00 PM PDT.
    func testWeekendNothingTrading() throws {
        let now = try makeDate(year: 2026, month: 8, day: 29, hour: 11, minute: 40)
        let resolved = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
        let focus = FocusSessionResolver().resolve(resolved, at: now)

        XCTAssertTrue(focus.openEntries.isEmpty)
        XCTAssertNil(focus.hero)

        let next = try XCTUnwrap(focus.nextToOpen)
        XCTAssertEqual(next.sessionID, .cmeFutures)
        XCTAssertEqual(
            next.opensAt,
            try makeDate(year: 2026, month: 8, day: 30, hour: 15, minute: 0)
        )
        // Gap runs Friday 2:00 PM PDT close → Sunday 3:00 PM PDT open (49h); 21h40m elapsed.
        XCTAssertEqual(next.fillFraction, 1_300.0 / 2_940.0, accuracy: 0.000_001)
        XCTAssertEqual(next.remainingMinutes, 1_640)
    }

    // Overnight: NY closed, CME and Asia open — CME (priority 2) is the hero.
    func testHeroUsesFocusPriorityAmongOpenSessions() throws {
        // Monday 2026-08-24 8:00 PM PDT = Tuesday 12:00 PM JST (Tokyo afternoon session).
        let now = try makeDate(year: 2026, month: 8, day: 24, hour: 21, minute: 0)
        let resolved = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
        let focus = FocusSessionResolver().resolve(resolved, at: now)

        XCTAssertEqual(focus.hero?.sessionID, .cmeFutures)
        XCTAssertTrue(focus.openEntries.count >= 2)
        // Everything after the hero is ordered by nearest transition.
        let secondaryDates = focus.secondary.map(\.transition.date)
        XCTAssertEqual(secondaryDates, secondaryDates.sorted())
    }

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
