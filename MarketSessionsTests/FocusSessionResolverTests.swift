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

    // Menu bar: the nearest transition is London's 8:30 AM close, so a filled pill and its clock time.
    func testMenuBarShowsFilledPillAndCloseTimeForNearestTransition() throws {
        let now = try makeDate(year: 2026, month: 8, day: 28, hour: 7, minute: 12)
        let resolved = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
        let next = try XCTUnwrap(
            resolved.min { ($0.transition?.date ?? .distantFuture) < ($1.transition?.date ?? .distantFuture) }
        )

        XCTAssertEqual(next.id, .london)
        XCTAssertTrue(MenuBarLabel.isFilled(next))
        XCTAssertEqual(try menuBarTime(next, now: now), "8:30\u{202F}AM")
    }

    // Saturday: nothing trading, so an outlined pill and CME's Sunday 3:00 PM open with its weekday.
    func testMenuBarShowsOutlinedPillAndWeekdayWhileCountingToAnOpen() throws {
        let now = try makeDate(year: 2026, month: 8, day: 29, hour: 11, minute: 40)
        let resolved = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)
        let next = try XCTUnwrap(
            resolved.min { ($0.transition?.date ?? .distantFuture) < ($1.transition?.date ?? .distantFuture) }
        )

        XCTAssertEqual(next.id, .cmeFutures)
        XCTAssertFalse(MenuBarLabel.isFilled(next))
        XCTAssertEqual(try menuBarTime(next, now: now), "Sun 3:00\u{202F}PM")
    }

    /// Not normalized: the menu bar keeps the system clock's narrow space (U+202F) before AM/PM.
    private func menuBarTime(_ resolved: ResolvedSession, now: Date) throws -> String {
        try XCTUnwrap(MenuBarLabel.time(
            for: resolved, now: now,
            timeZone: try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles")),
            locale: Locale(identifier: "en_US")
        ))
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
