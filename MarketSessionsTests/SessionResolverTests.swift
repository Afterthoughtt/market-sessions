import ServiceManagement
import XCTest
@testable import MarketSessions

final class SessionResolverTests: XCTestCase {
    func testEverySessionIsActiveAtItsRecurringOpen() throws {
        let cases: [(MarketSession.ID, String, Int, Int, Int, Int, Int)] = [
            (.cmeMacroFutures, "America/Chicago", 2026, 8, 23, 17, 0),
            (.tokyo, "Asia/Tokyo", 2026, 8, 24, 9, 0),
            (.hongKong, "Asia/Hong_Kong", 2026, 8, 24, 9, 30),
            (.shanghai, "Asia/Shanghai", 2026, 8, 24, 9, 30),
            (.london, "Europe/London", 2026, 8, 24, 8, 0),
            (.newYorkFX, "America/New_York", 2026, 8, 24, 8, 0),
            (.newYorkCash, "America/New_York", 2026, 8, 24, 9, 30),
            (.spotFX, "America/New_York", 2026, 8, 23, 17, 0),
            (.cryptoUTC, "UTC", 2026, 8, 24, 0, 0),
        ]

        for item in cases {
            let now = try makeDate(
                year: item.2,
                month: item.3,
                day: item.4,
                hour: item.5,
                minute: item.6,
                timeZoneIdentifier: item.1
            )
            let result = SessionResolver().resolve(MarketScheduleCatalog.session(item.0), at: now)
            XCTAssertTrue(result.status.isActive, "Expected \(item.0) to be active at its open")
            XCTAssertEqual(result.currentOccurrence?.start, now)
        }
    }

    func testExactCloseBoundariesDoNotRemainActive() throws {
        let cases: [(MarketSession.ID, String, Int, Int, Int, Int, Int)] = [
            (.cmeMacroFutures, "America/Chicago", 2026, 8, 28, 16, 0),
            (.tokyo, "Asia/Tokyo", 2026, 8, 24, 15, 30),
            (.hongKong, "Asia/Hong_Kong", 2026, 8, 24, 16, 0),
            (.shanghai, "Asia/Shanghai", 2026, 8, 24, 15, 0),
            (.london, "Europe/London", 2026, 8, 24, 16, 30),
            (.newYorkFX, "America/New_York", 2026, 8, 24, 17, 0),
            (.newYorkCash, "America/New_York", 2026, 8, 24, 16, 0),
            (.spotFX, "America/New_York", 2026, 8, 28, 17, 0),
        ]

        for item in cases {
            let now = try makeDate(
                year: item.2,
                month: item.3,
                day: item.4,
                hour: item.5,
                minute: item.6,
                timeZoneIdentifier: item.1
            )
            let result = SessionResolver().resolve(MarketScheduleCatalog.session(item.0), at: now)
            XCTAssertFalse(result.status.isActive, "Expected \(item.0) to transition at its close")
        }
    }

    func testCryptoBoundaryImmediatelyStartsTheNextUTCSession() throws {
        let boundary = try makeDate(
            year: 2026,
            month: 8,
            day: 24,
            hour: 0,
            minute: 0,
            timeZoneIdentifier: "UTC"
        )
        let result = SessionResolver().resolve(MarketScheduleCatalog.session(.cryptoUTC), at: boundary)

        XCTAssertTrue(result.status.isActive)
        XCTAssertEqual(result.currentOccurrence?.start, boundary)
    }

    func testAsianLunchRecessesAndAuctionPhases() throws {
        let cases: [(MarketSession.ID, String, Int, Int, SessionStatus)] = [
            (.tokyo, "Asia/Tokyo", 11, 45, .recess("Lunch recess")),
            (.hongKong, "Asia/Hong_Kong", 12, 30, .recess("Lunch recess")),
            (.shanghai, "Asia/Shanghai", 12, 15, .recess("Lunch recess")),
            (.hongKong, "Asia/Hong_Kong", 16, 5, .informational("Closing auction")),
            (.shanghai, "Asia/Shanghai", 14, 58, .active(phase: "Closing auction")),
        ]

        for item in cases {
            let now = try makeDate(
                year: 2026,
                month: 8,
                day: 24,
                hour: item.2,
                minute: item.3,
                timeZoneIdentifier: item.1
            )
            let result = SessionResolver().resolve(MarketScheduleCatalog.session(item.0), at: now)
            XCTAssertEqual(result.status, item.4)
        }
    }

    func testCMEMaintenanceFridayCloseAndSundayReopen() throws {
        let session = MarketScheduleCatalog.session(.cmeMacroFutures)
        let maintenance = try makeDate(
            year: 2026, month: 8, day: 24, hour: 16, minute: 30,
            timeZoneIdentifier: "America/Chicago"
        )
        let fridayClosed = try makeDate(
            year: 2026, month: 8, day: 28, hour: 16, minute: 30,
            timeZoneIdentifier: "America/Chicago"
        )
        let sundayOpen = try makeDate(
            year: 2026, month: 8, day: 30, hour: 17, minute: 0,
            timeZoneIdentifier: "America/Chicago"
        )

        XCTAssertEqual(SessionResolver().resolve(session, at: maintenance).status, .maintenance("Daily maintenance"))
        XCTAssertEqual(SessionResolver().resolve(session, at: fridayClosed).status, .closed)
        XCTAssertTrue(SessionResolver().resolve(session, at: sundayOpen).status.isActive)
    }

    func testWeekendNextTransitionsCrossTheWeekBoundary() throws {
        let saturday = try makeDate(
            year: 2026, month: 8, day: 29, hour: 12, minute: 0,
            timeZoneIdentifier: "America/New_York"
        )
        let cash = SessionResolver().resolve(MarketScheduleCatalog.session(.newYorkCash), at: saturday)
        let cme = SessionResolver().resolve(MarketScheduleCatalog.session(.cmeMacroFutures), at: saturday)

        XCTAssertEqual(cash.status, .closed)
        XCTAssertEqual(cash.transition?.kind, .opens)
        XCTAssertEqual(cme.status, .closed)
        XCTAssertEqual(cme.transition?.kind, .opens)
        XCTAssertLessThan(cme.transition!.date, cash.transition!.date)
    }

    func testLondonOpenTracksMismatchedDSTWeeks() throws {
        let vancouver = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let resolver = SessionResolver(displayTimeZone: vancouver)
        let london = MarketScheduleCatalog.session(.london)
        let beforeEuropeanDST = try makeDate(
            year: 2026, month: 3, day: 23, hour: 0, minute: 0,
            timeZoneIdentifier: "America/Vancouver"
        )
        let afterEuropeanDST = try makeDate(
            year: 2026, month: 3, day: 30, hour: 0, minute: 0,
            timeZoneIdentifier: "America/Vancouver"
        )

        let firstOpen = try XCTUnwrap(resolver.resolve(london, at: beforeEuropeanDST).nextActiveOccurrence?.start)
        let secondResult = resolver.resolve(london, at: afterEuropeanDST)
        let secondOpen = try XCTUnwrap(secondResult.currentOccurrence?.start)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = vancouver

        XCTAssertEqual(calendar.component(.hour, from: firstOpen), 1)
        XCTAssertEqual(calendar.component(.hour, from: secondOpen), 0)
    }

    func testNewYorkScheduleTracksUSSpringDSTBoundary() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let resolver = SessionResolver(displayTimeZone: utc)
        let cash = MarketScheduleCatalog.session(.newYorkCash)
        let beforeDST = try makeDate(
            year: 2026, month: 3, day: 6, hour: 13, minute: 0,
            timeZoneIdentifier: "UTC"
        )
        let afterDST = try makeDate(
            year: 2026, month: 3, day: 9, hour: 12, minute: 0,
            timeZoneIdentifier: "UTC"
        )
        let winterOpen = try XCTUnwrap(resolver.resolve(cash, at: beforeDST).nextActiveOccurrence?.start)
        let summerOpen = try XCTUnwrap(resolver.resolve(cash, at: afterDST).nextActiveOccurrence?.start)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc

        XCTAssertEqual(calendar.component(.hour, from: winterOpen), 14)
        XCTAssertEqual(calendar.component(.minute, from: winterOpen), 30)
        XCTAssertEqual(calendar.component(.hour, from: summerOpen), 13)
        XCTAssertEqual(calendar.component(.minute, from: summerOpen), 30)
    }

    func testAsianCanonicalTimeDoesNotAcquireDST() throws {
        let tokyo = MarketScheduleCatalog.session(.tokyo)
        let tokyoZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyoZone
        let winter = try makeDate(
            year: 2026, month: 1, day: 5, hour: 8, minute: 0,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        let summer = try makeDate(
            year: 2026, month: 7, day: 6, hour: 8, minute: 0,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        let winterOpen = try XCTUnwrap(SessionResolver().resolve(tokyo, at: winter).nextActiveOccurrence?.start)
        let summerOpen = try XCTUnwrap(SessionResolver().resolve(tokyo, at: summer).nextActiveOccurrence?.start)

        XCTAssertEqual(calendar.component(.hour, from: winterOpen), 9)
        XCTAssertEqual(calendar.component(.hour, from: summerOpen), 9)
    }

    func testDisplayTimeZoneChangesPresentationNotCanonicalOccurrence() throws {
        let now = try makeDate(
            year: 2026, month: 8, day: 24, hour: 23, minute: 0,
            timeZoneIdentifier: "UTC"
        )
        let session = MarketScheduleCatalog.session(.newYorkCash)
        let vancouver = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let berlin = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let vancouverResult = SessionResolver(displayTimeZone: vancouver).resolve(session, at: now)
        let berlinResult = SessionResolver(displayTimeZone: berlin).resolve(session, at: now)

        XCTAssertEqual(vancouverResult.nextActiveOccurrence?.start, berlinResult.nextActiveOccurrence?.start)
        XCTAssertNotEqual(vancouverResult.todayIntervals, berlinResult.todayIntervals)
    }

    func testLoginItemStatusMappingIsPure() {
        XCTAssertEqual(LoginItemService.map(.enabled), .enabled)
        XCTAssertEqual(LoginItemService.map(.notRegistered), .disabled)
        XCTAssertEqual(LoginItemService.map(.requiresApproval), .requiresApproval)
        XCTAssertEqual(LoginItemService.map(.notFound), .unavailable)
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
        return try XCTUnwrap(
            calendar.date(from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            ))
        )
    }
}
