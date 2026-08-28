import XCTest
@testable import MarketSessions

final class MarketExceptionTests: XCTestCase {
    private func bundledResolver() throws -> SessionResolver {
        let index = try MarketExceptionCatalog.loadIndex(bundle: Bundle(for: Self.self))
        return SessionResolver(exceptions: index)
    }

    func testBundledFileLoadsWithCoverage() throws {
        let index = try MarketExceptionCatalog.loadIndex(bundle: Bundle(for: Self.self))
        let coverage = try XCTUnwrap(index.coverageEnd)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(
            calendar.dateComponents([.year, .month, .day], from: coverage),
            DateComponents(year: 2026, month: 12, day: 31)
        )
    }

    func testNYSEClosesAtOneOnDayAfterThanksgiving() throws {
        let zone = "America/New_York"
        let now = try makeDate(year: 2026, month: 11, day: 27, hour: 10, minute: 0, timeZone: zone)
        let result = try bundledResolver().resolve(MarketScheduleCatalog.session(.newYorkCash), at: now)

        XCTAssertEqual(result.status, .open)
        XCTAssertEqual(
            result.transition?.date,
            try makeDate(year: 2026, month: 11, day: 27, hour: 13, minute: 0, timeZone: zone)
        )
    }

    func testNYSEClosedOnThanksgiving() throws {
        let zone = "America/New_York"
        let now = try makeDate(year: 2026, month: 11, day: 26, hour: 12, minute: 0, timeZone: zone)
        let result = try bundledResolver().resolve(MarketScheduleCatalog.session(.newYorkCash), at: now)

        XCTAssertEqual(result.status, .closed)
        XCTAssertEqual(
            result.nextActiveStart,
            try makeDate(year: 2026, month: 11, day: 27, hour: 9, minute: 30, timeZone: zone)
        )
    }

    func testCMEThanksgivingHaltsThenReopensSameEvening() throws {
        let zone = "America/Chicago"
        let resolver = try bundledResolver()

        let morning = try makeDate(year: 2026, month: 11, day: 26, hour: 10, minute: 0, timeZone: zone)
        let open = resolver.resolve(MarketScheduleCatalog.session(.cmeFutures), at: morning)
        XCTAssertEqual(open.status, .open)
        XCTAssertEqual(
            open.transition?.date,
            try makeDate(year: 2026, month: 11, day: 26, hour: 12, minute: 0, timeZone: zone)
        )

        let halted = try makeDate(year: 2026, month: 11, day: 26, hour: 14, minute: 0, timeZone: zone)
        let closed = resolver.resolve(MarketScheduleCatalog.session(.cmeFutures), at: halted)
        XCTAssertEqual(closed.status, .closed)
        XCTAssertEqual(
            closed.nextActiveStart,
            try makeDate(year: 2026, month: 11, day: 26, hour: 17, minute: 0, timeZone: zone)
        )
    }

    func testCMEChristmasEveFinalCloseWithNoEveningReopen() throws {
        let zone = "America/Chicago"
        // Dec 24 closes 12:15 CT; Dec 25 is a holiday, so the Thursday evening
        // session never opens. Next open is Sunday Dec 27 17:00 CT.
        let now = try makeDate(year: 2026, month: 12, day: 24, hour: 14, minute: 0, timeZone: zone)
        let result = try bundledResolver().resolve(MarketScheduleCatalog.session(.cmeFutures), at: now)

        XCTAssertEqual(result.status, .closed)
        XCTAssertEqual(
            result.nextActiveStart,
            try makeDate(year: 2026, month: 12, day: 27, hour: 17, minute: 0, timeZone: zone)
        )
    }

    func testShanghaiGoldenWeekClosure() throws {
        let zone = "Asia/Shanghai"
        let now = try makeDate(year: 2026, month: 10, day: 5, hour: 10, minute: 0, timeZone: zone)
        let result = try bundledResolver().resolve(MarketScheduleCatalog.session(.shanghai), at: now)

        XCTAssertEqual(result.status, .closed)
        XCTAssertEqual(
            result.nextActiveStart,
            try makeDate(year: 2026, month: 10, day: 8, hour: 9, minute: 30, timeZone: zone)
        )
    }

    func testHongKongChristmasEveHalfDay() throws {
        let zone = "Asia/Hong_Kong"
        let now = try makeDate(year: 2026, month: 12, day: 24, hour: 14, minute: 0, timeZone: zone)
        let result = try bundledResolver().resolve(MarketScheduleCatalog.session(.hongKong), at: now)

        // Afternoon session and closing auction are dropped; Dec 25 is a holiday,
        // so the next open is Monday Dec 28.
        XCTAssertEqual(result.status, .closed)
        XCTAssertEqual(
            result.nextActiveStart,
            try makeDate(year: 2026, month: 12, day: 28, hour: 9, minute: 30, timeZone: zone)
        )
    }

    func testTokyoSilverWeekClosure() throws {
        let zone = "Asia/Tokyo"
        // Sep 21-23 are consecutive holidays; Friday Sep 18 is the last session.
        let now = try makeDate(year: 2026, month: 9, day: 21, hour: 10, minute: 0, timeZone: zone)
        let result = try bundledResolver().resolve(MarketScheduleCatalog.session(.tokyo), at: now)

        XCTAssertEqual(result.status, .closed)
        XCTAssertEqual(
            result.nextActiveStart,
            try makeDate(year: 2026, month: 9, day: 24, hour: 9, minute: 0, timeZone: zone)
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZone identifier: String
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = try XCTUnwrap(TimeZone(identifier: identifier))
        calendar.timeZone = timeZone
        let components = DateComponents(
            timeZone: timeZone, year: year, month: month, day: day, hour: hour, minute: minute
        )
        return try XCTUnwrap(calendar.date(from: components))
    }
}
