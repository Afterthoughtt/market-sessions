import XCTest
@testable import MarketSessions

final class SessionResolverTests: XCTestCase {
    // Monday 2026-08-24; CME's week opens Sunday 2026-08-23 17:00 CT.
    func testEverySessionIsActiveAtItsRecurringOpen() throws {
        let cases: [(MarketSession.ID, String, Int, Int, Int, Int, Int)] = [
            (.cmeFutures, "America/Chicago", 2026, 8, 23, 17, 0),
            (.tokyo, "Asia/Tokyo", 2026, 8, 24, 9, 0),
            (.hongKong, "Asia/Hong_Kong", 2026, 8, 24, 9, 30),
            (.shanghai, "Asia/Shanghai", 2026, 8, 24, 9, 30),
            (.london, "Europe/London", 2026, 8, 24, 8, 0),
            (.newYorkCash, "America/New_York", 2026, 8, 24, 9, 30),
        ]

        for item in cases {
            let now = try makeDate(
                year: item.2, month: item.3, day: item.4, hour: item.5, minute: item.6,
                timeZoneIdentifier: item.1
            )
            let result = SessionResolver().resolve(MarketScheduleCatalog.session(item.0), at: now)
            XCTAssertTrue(result.status.isActive, "Expected \(item.0) to be active at its open")
            XCTAssertEqual(result.currentOccurrence?.start, now)
        }
    }

    func testExactCloseBoundariesDoNotRemainActive() throws {
        let cases: [(MarketSession.ID, String, Int, Int, Int, Int, Int)] = [
            (.cmeFutures, "America/Chicago", 2026, 8, 28, 16, 0),
            (.tokyo, "Asia/Tokyo", 2026, 8, 24, 15, 30),
            (.hongKong, "Asia/Hong_Kong", 2026, 8, 24, 16, 10),
            (.shanghai, "Asia/Shanghai", 2026, 8, 24, 15, 0),
            (.london, "Europe/London", 2026, 8, 24, 16, 30),
            (.newYorkCash, "America/New_York", 2026, 8, 24, 16, 0),
        ]

        for item in cases {
            let now = try makeDate(
                year: item.2, month: item.3, day: item.4, hour: item.5, minute: item.6,
                timeZoneIdentifier: item.1
            )
            let result = SessionResolver().resolve(MarketScheduleCatalog.session(item.0), at: now)
            XCTAssertFalse(result.status.isActive, "Expected \(item.0) to be inactive at its close")
        }
    }

    func testTokyoMorningBreaksIntoLunchRecess() throws {
        let now = try makeDate(
            year: 2026, month: 8, day: 24, hour: 10, minute: 0,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        let result = SessionResolver().resolve(MarketScheduleCatalog.session(.tokyo), at: now)
        XCTAssertEqual(result.status, .open)
        XCTAssertEqual(result.transition?.verb, .breaks)
        XCTAssertEqual(
            result.transition?.date,
            try makeDate(year: 2026, month: 8, day: 24, hour: 11, minute: 30, timeZoneIdentifier: "Asia/Tokyo")
        )
    }

    func testTokyoLunchRecessResumes() throws {
        let now = try makeDate(
            year: 2026, month: 8, day: 24, hour: 12, minute: 0,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        let result = SessionResolver().resolve(MarketScheduleCatalog.session(.tokyo), at: now)
        XCTAssertEqual(result.status, .recess)
        XCTAssertEqual(result.transition?.verb, .resumes)
        XCTAssertEqual(
            result.transition?.date,
            try makeDate(year: 2026, month: 8, day: 24, hour: 12, minute: 30, timeZoneIdentifier: "Asia/Tokyo")
        )
    }

    func testShanghaiClosingAuctionStatusAndChainedClose() throws {
        let zone = "Asia/Shanghai"
        let auctionNow = try makeDate(year: 2026, month: 8, day: 24, hour: 14, minute: 58, timeZoneIdentifier: zone)
        let auction = SessionResolver().resolve(MarketScheduleCatalog.session(.shanghai), at: auctionNow)
        XCTAssertEqual(auction.status, .auction)
        XCTAssertEqual(auction.transition?.verb, .closes)
        XCTAssertEqual(
            auction.transition?.date,
            try makeDate(year: 2026, month: 8, day: 24, hour: 15, minute: 0, timeZoneIdentifier: zone)
        )

        // While continuously trading, the close is the end of the whole chain (through the auction).
        let tradingNow = try makeDate(year: 2026, month: 8, day: 24, hour: 14, minute: 0, timeZoneIdentifier: zone)
        let trading = SessionResolver().resolve(MarketScheduleCatalog.session(.shanghai), at: tradingNow)
        XCTAssertEqual(trading.status, .open)
        XCTAssertEqual(trading.transition?.verb, .closes)
        XCTAssertEqual(
            trading.transition?.date,
            try makeDate(year: 2026, month: 8, day: 24, hour: 15, minute: 0, timeZoneIdentifier: zone)
        )
    }

    func testHongKongClosingAuction() throws {
        let now = try makeDate(
            year: 2026, month: 8, day: 24, hour: 16, minute: 5,
            timeZoneIdentifier: "Asia/Hong_Kong"
        )
        let result = SessionResolver().resolve(MarketScheduleCatalog.session(.hongKong), at: now)
        XCTAssertEqual(result.status, .auction)
        XCTAssertEqual(result.transition?.verb, .closes)
    }

    func testCMEWeekdayBreaksAndMaintenanceAndFridayClose() throws {
        let zone = "America/Chicago"
        let session = MarketScheduleCatalog.session(.cmeFutures)

        let monday = try makeDate(year: 2026, month: 8, day: 24, hour: 12, minute: 0, timeZoneIdentifier: zone)
        let open = SessionResolver().resolve(session, at: monday)
        XCTAssertEqual(open.status, .open)
        XCTAssertEqual(open.transition?.verb, .breaks)
        XCTAssertEqual(open.transition?.approximate, true)

        let maintenanceNow = try makeDate(year: 2026, month: 8, day: 24, hour: 16, minute: 30, timeZoneIdentifier: zone)
        let maintenance = SessionResolver().resolve(session, at: maintenanceNow)
        XCTAssertEqual(maintenance.status, .maintenance)
        XCTAssertEqual(maintenance.transition?.verb, .reopens)
        XCTAssertEqual(
            maintenance.transition?.date,
            try makeDate(year: 2026, month: 8, day: 24, hour: 17, minute: 0, timeZoneIdentifier: zone)
        )

        // Friday's 4:00 PM CT end is the weekly close, not a maintenance break.
        let friday = try makeDate(year: 2026, month: 8, day: 28, hour: 12, minute: 0, timeZoneIdentifier: zone)
        let fridayResolved = SessionResolver().resolve(session, at: friday)
        XCTAssertEqual(fridayResolved.status, .open)
        XCTAssertEqual(fridayResolved.transition?.verb, .closes)
    }

    func testSaturdayEverythingClosedWithOpensTransitions() throws {
        let now = try makeDate(
            year: 2026, month: 8, day: 29, hour: 11, minute: 40,
            timeZoneIdentifier: "America/Los_Angeles"
        )
        let resolved = SessionResolver().resolve(MarketScheduleCatalog.sessions, at: now)

        for result in resolved {
            XCTAssertEqual(result.status, .closed, "\(result.id) should be closed on Saturday")
            XCTAssertEqual(result.transition?.verb, .opens)
        }

        let cme = try XCTUnwrap(resolved.first(where: { $0.id == .cmeFutures }))
        XCTAssertEqual(
            cme.transition?.date,
            try makeDate(year: 2026, month: 8, day: 30, hour: 17, minute: 0, timeZoneIdentifier: "America/Chicago")
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
        let timeZone = try XCTUnwrap(TimeZone(identifier: timeZoneIdentifier))
        calendar.timeZone = timeZone
        let components = DateComponents(
            timeZone: timeZone, year: year, month: month, day: day, hour: hour, minute: minute
        )
        return try XCTUnwrap(calendar.date(from: components))
    }
}
