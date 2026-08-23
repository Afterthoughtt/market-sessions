import XCTest
@testable import MarketSessions

final class ProgressTests: XCTestCase {
    func testTokyoProgressExcludesLunchRecess() throws {
        let morning = try makeDate(
            year: 2026, month: 8, day: 24, hour: 10, minute: 15,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        let afternoon = try makeDate(
            year: 2026, month: 8, day: 24, hour: 13, minute: 30,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        let resolver = SessionResolver()
        let focusResolver = FocusSessionResolver()
        let tokyo = MarketScheduleCatalog.session(.tokyo)

        let morningFocus = try XCTUnwrap(focusResolver.resolve([resolver.resolve(tokyo, at: morning)], at: morning))
        let afternoonFocus = try XCTUnwrap(focusResolver.resolve([resolver.resolve(tokyo, at: afternoon)], at: afternoon))

        XCTAssertEqual(morningFocus.progress, 75.0 / 330.0, accuracy: 0.000_001)
        XCTAssertEqual(afternoonFocus.progress, 210.0 / 330.0, accuracy: 0.000_001)
    }

    func testUpcomingProgressRunsFromPrecedingCloseToNextOpen() throws {
        let lunchMidpoint = try makeDate(
            year: 2026, month: 8, day: 24, hour: 12, minute: 0,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        let row = SessionResolver().resolve(MarketScheduleCatalog.session(.tokyo), at: lunchMidpoint)
        let focus = try XCTUnwrap(FocusSessionResolver().resolve([row], at: lunchMidpoint))

        XCTAssertEqual(focus.mode, .upcoming)
        XCTAssertEqual(focus.progress, 0.5, accuracy: 0.000_001)
    }

    func testCMEActiveProgressAtMidpoint() throws {
        let midpoint = try makeDate(
            year: 2026, month: 8, day: 24, hour: 4, minute: 30,
            timeZoneIdentifier: "America/Chicago"
        )
        let row = SessionResolver().resolve(MarketScheduleCatalog.session(.cmeMacroFutures), at: midpoint)
        let focus = try XCTUnwrap(FocusSessionResolver().resolve([row], at: midpoint))

        XCTAssertEqual(focus.progress, 0.5, accuracy: 0.000_001)
    }

    func testActiveProgressStartsAtZeroAndApproachesOne() throws {
        let open = try makeDate(
            year: 2026, month: 8, day: 24, hour: 9, minute: 30,
            timeZoneIdentifier: "America/New_York"
        )
        let beforeClose = try makeDate(
            year: 2026, month: 8, day: 24, hour: 15, minute: 59,
            timeZoneIdentifier: "America/New_York"
        )
        let resolver = SessionResolver()
        let focusResolver = FocusSessionResolver()
        let cash = MarketScheduleCatalog.session(.newYorkCash)
        let atOpen = try XCTUnwrap(focusResolver.resolve([resolver.resolve(cash, at: open)], at: open))
        let nearClose = try XCTUnwrap(
            focusResolver.resolve([resolver.resolve(cash, at: beforeClose)], at: beforeClose)
        )

        XCTAssertEqual(atOpen.progress, 0)
        XCTAssertGreaterThan(nearClose.progress, 0.99)
        XCTAssertLessThan(nearClose.progress, 1)
    }

    func testProgressClampsAtBothEnds() {
        let start = Date(timeIntervalSince1970: 10_000)
        let end = start.addingTimeInterval(100)

        XCTAssertEqual(
            FocusSessionResolver.clampedProgress(now: start.addingTimeInterval(-10), start: start, end: end),
            0
        )
        XCTAssertEqual(
            FocusSessionResolver.clampedProgress(now: end.addingTimeInterval(10), start: start, end: end),
            1
        )
    }

    func testInvalidProgressBoundariesReturnZeroInsteadOfNaN() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertEqual(FocusSessionResolver.clampedProgress(now: now, start: nil, end: now), 0)
        XCTAssertEqual(FocusSessionResolver.clampedProgress(now: now, start: now, end: nil), 0)
        XCTAssertEqual(FocusSessionResolver.clampedProgress(now: now, start: now, end: now), 0)
        XCTAssertEqual(
            FocusSessionResolver.clampedProgress(
                now: now,
                start: now,
                end: now.addingTimeInterval(-1)
            ),
            0
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
