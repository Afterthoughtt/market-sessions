import XCTest
@testable import MarketSessions

final class SessionResolverTests: XCTestCase {
    func testMarketStateLabels() {
        XCTAssertEqual(Set(SessionStatus.allCases.map(\.label)), ["Open", "Pre-Market", "After Hours", "Break", "Closed"])
    }

    func testCMEUsesScheduledBoundaryWithoutEstimateMarker() throws {
        let now = try makeDate(
            year: 2026, month: 8, day: 24, hour: 12, minute: 0,
            timeZoneIdentifier: "America/Chicago"
        )
        let cme = SessionResolver().resolve(MarketScheduleCatalog.session(.cmeFutures), at: now)
        let close = try XCTUnwrap(cme.transition?.date)
        XCTAssertEqual(close, try makeDate(
            year: 2026, month: 8, day: 24, hour: 16, minute: 0,
            timeZoneIdentifier: "America/Chicago"
        ))
        let text = MarketDateFormatting.transitionTime(
            close, relativeTo: now,
            timeZone: try XCTUnwrap(TimeZone(identifier: "America/Vancouver")),
            locale: Locale(identifier: "en_US_POSIX")
        )
        XCTAssertFalse(text.contains("≈"))
        XCTAssertEqual(text.replacingOccurrences(of: "\u{202F}", with: " "), "2:00 PM")
    }

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

    func testTokyoMorningClosesAtLunchRecess() throws {
        let now = try makeDate(
            year: 2026, month: 8, day: 24, hour: 10, minute: 0,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        let result = SessionResolver().resolve(MarketScheduleCatalog.session(.tokyo), at: now)
        XCTAssertEqual(result.status, .open)
        XCTAssertEqual(result.transition?.verb, .closes)
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
        XCTAssertEqual(result.status, .onBreak)
        XCTAssertEqual(result.transition?.verb, .opens)
        XCTAssertEqual(
            result.transition?.date,
            try makeDate(year: 2026, month: 8, day: 24, hour: 12, minute: 30, timeZoneIdentifier: "Asia/Tokyo")
        )
    }

    func testShanghaiClosingAuctionStatusAndChainedClose() throws {
        let zone = "Asia/Shanghai"
        let auctionNow = try makeDate(year: 2026, month: 8, day: 24, hour: 14, minute: 58, timeZoneIdentifier: zone)
        let auction = SessionResolver().resolve(MarketScheduleCatalog.session(.shanghai), at: auctionNow)
        XCTAssertEqual(auction.status, .open)
        XCTAssertEqual(auction.currentOccurrence?.kind, .auction)
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
        XCTAssertEqual(result.status, .open)
        XCTAssertEqual(result.currentOccurrence?.kind, .auction)
        XCTAssertEqual(result.transition?.verb, .closes)
    }

    func testCMEWeekdayCloseAndMaintenance() throws {
        let zone = "America/Chicago"
        let session = MarketScheduleCatalog.session(.cmeFutures)

        let monday = try makeDate(year: 2026, month: 8, day: 24, hour: 12, minute: 0, timeZoneIdentifier: zone)
        let open = SessionResolver().resolve(session, at: monday)
        XCTAssertEqual(open.status, .open)
        XCTAssertEqual(open.transition?.verb, .closes)

        let maintenanceNow = try makeDate(year: 2026, month: 8, day: 24, hour: 16, minute: 30, timeZoneIdentifier: zone)
        let maintenance = SessionResolver().resolve(session, at: maintenanceNow)
        XCTAssertEqual(maintenance.status, .onBreak)
        XCTAssertEqual(maintenance.transition?.verb, .opens)
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

    func testNewYorkPreAndPostMarket() throws {
        let zone = "America/New_York"
        let session = MarketScheduleCatalog.session(.newYorkCash)

        let preMarket = try makeDate(year: 2026, month: 8, day: 24, hour: 8, minute: 0, timeZoneIdentifier: zone)
        let pre = SessionResolver().resolve(session, at: preMarket)
        XCTAssertEqual(pre.status, .preMarket)
        XCTAssertEqual(pre.currentOccurrence?.kind, .preMarket)
        XCTAssertFalse(pre.status.isActive)
        XCTAssertEqual(pre.transition?.verb, .opens)
        XCTAssertEqual(
            pre.transition?.date,
            try makeDate(year: 2026, month: 8, day: 24, hour: 9, minute: 30, timeZoneIdentifier: zone)
        )

        let postMarket = try makeDate(year: 2026, month: 8, day: 24, hour: 17, minute: 0, timeZoneIdentifier: zone)
        let post = SessionResolver().resolve(session, at: postMarket)
        XCTAssertEqual(post.status, .postMarket)
        XCTAssertEqual(post.currentOccurrence?.kind, .postMarket)
        XCTAssertFalse(post.status.isActive)
        XCTAssertEqual(post.transition?.verb, .opens)
        XCTAssertEqual(
            post.transition?.date,
            try makeDate(year: 2026, month: 8, day: 25, hour: 9, minute: 30, timeZoneIdentifier: zone)
        )
    }

    // Exchange pre-open windows (auction call or order acceptance) resolve to
    // Pre-Market and point at the continuous-trading open.
    func testExchangePreOpenWindowsResolveToPreMarket() throws {
        let cases: [(MarketSession.ID, String, Int, Int, Int, Int)] = [
            (.london, "Europe/London", 7, 55, 8, 0),
            (.tokyo, "Asia/Tokyo", 8, 30, 9, 0),
            (.hongKong, "Asia/Hong_Kong", 9, 10, 9, 30),
            (.shanghai, "Asia/Shanghai", 9, 27, 9, 30),
        ]

        for item in cases {
            let now = try makeDate(year: 2026, month: 8, day: 24, hour: item.2, minute: item.3, timeZoneIdentifier: item.1)
            let result = SessionResolver().resolve(MarketScheduleCatalog.session(item.0), at: now)
            XCTAssertEqual(result.status, .preMarket, "\(item.0)")
            XCTAssertFalse(result.status.isActive, "\(item.0)")
            XCTAssertEqual(result.transition?.verb, .opens, "\(item.0)")
            XCTAssertEqual(
                result.transition?.date,
                try makeDate(year: 2026, month: 8, day: 24, hour: item.4, minute: item.5, timeZoneIdentifier: item.1),
                "\(item.0)"
            )
        }
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

    func testHolidayRemovesTheWholeTradingDay() throws {
        // Synthetic: NY holiday on Monday 2026-08-24.
        let exceptions = MarketExceptionIndex(
            exceptions: [
                MarketException(market: .newYorkCash, year: 2026, month: 8, day: 24, kind: .holiday, close: nil, note: nil)
            ],
            coverageEnd: nil
        )
        let resolver = SessionResolver(exceptions: exceptions)
        let now = try makeDate(year: 2026, month: 8, day: 24, hour: 12, minute: 0, timeZoneIdentifier: "America/New_York")
        let result = resolver.resolve(MarketScheduleCatalog.session(.newYorkCash), at: now)

        XCTAssertEqual(result.status, .closed)
        // Next open is Tuesday, not later today.
        XCTAssertEqual(
            result.nextActiveStart,
            try makeDate(year: 2026, month: 8, day: 25, hour: 9, minute: 30, timeZoneIdentifier: "America/New_York")
        )
    }

    func testEarlyCloseClampsTheSessionAndDropsTheAfternoon() throws {
        let zone = "America/New_York"
        // Synthetic: NY early close 13:00 on Friday 2026-08-28 (like Nov 27 / Dec 24).
        let exceptions = MarketExceptionIndex(
            exceptions: [
                MarketException(market: .newYorkCash, year: 2026, month: 8, day: 28, kind: .earlyClose, close: LocalTime(13), note: nil)
            ],
            coverageEnd: nil
        )
        let resolver = SessionResolver(exceptions: exceptions)

        let morning = try makeDate(year: 2026, month: 8, day: 28, hour: 12, minute: 0, timeZoneIdentifier: zone)
        let open = resolver.resolve(MarketScheduleCatalog.session(.newYorkCash), at: morning)
        XCTAssertEqual(open.status, .open)
        XCTAssertEqual(
            open.transition?.date,
            try makeDate(year: 2026, month: 8, day: 28, hour: 13, minute: 0, timeZoneIdentifier: zone)
        )

        // After the early close the session is closed — the shortened post-market is dropped.
        let afternoon = try makeDate(year: 2026, month: 8, day: 28, hour: 14, minute: 0, timeZoneIdentifier: zone)
        let closed = resolver.resolve(MarketScheduleCatalog.session(.newYorkCash), at: afternoon)
        XCTAssertEqual(closed.status, .closed)
    }

    func testCMEHolidayEarlyCloseKeepsTheEveningReopen() throws {
        let zone = "America/Chicago"
        // Synthetic Labor-Day-style: CME halts 12:00 CT Monday 2026-08-24, reopens 17:00.
        let exceptions = MarketExceptionIndex(
            exceptions: [
                MarketException(market: .cmeFutures, year: 2026, month: 8, day: 24, kind: .earlyClose, close: LocalTime(12), note: nil)
            ],
            coverageEnd: nil
        )
        let resolver = SessionResolver(exceptions: exceptions)

        let morning = try makeDate(year: 2026, month: 8, day: 24, hour: 10, minute: 0, timeZoneIdentifier: zone)
        let open = resolver.resolve(MarketScheduleCatalog.session(.cmeFutures), at: morning)
        XCTAssertEqual(open.status, .open)
        XCTAssertEqual(
            open.transition?.date,
            try makeDate(year: 2026, month: 8, day: 24, hour: 12, minute: 0, timeZoneIdentifier: zone)
        )

        // The Monday-evening session into Tuesday still opens at 17:00.
        let halted = try makeDate(year: 2026, month: 8, day: 24, hour: 14, minute: 0, timeZoneIdentifier: zone)
        let closed = resolver.resolve(MarketScheduleCatalog.session(.cmeFutures), at: halted)
        XCTAssertEqual(closed.status, .closed)
        XCTAssertEqual(
            closed.nextActiveStart,
            try makeDate(year: 2026, month: 8, day: 24, hour: 17, minute: 0, timeZoneIdentifier: zone)
        )
    }

    func testHalfDayDropsTheAfternoonSessionAndAuction() throws {
        let zone = "Asia/Hong_Kong"
        // Synthetic Christmas-Eve-style: HKG morning only, closes 12:00.
        let exceptions = MarketExceptionIndex(
            exceptions: [
                MarketException(market: .hongKong, year: 2026, month: 8, day: 24, kind: .earlyClose, close: LocalTime(12), note: nil)
            ],
            coverageEnd: nil
        )
        let resolver = SessionResolver(exceptions: exceptions)

        let afternoon = try makeDate(year: 2026, month: 8, day: 24, hour: 14, minute: 0, timeZoneIdentifier: zone)
        let result = resolver.resolve(MarketScheduleCatalog.session(.hongKong), at: afternoon)
        XCTAssertEqual(result.status, .closed)
        // Next open is Tuesday morning — no afternoon session, no closing auction today.
        XCTAssertEqual(
            result.nextActiveStart,
            try makeDate(year: 2026, month: 8, day: 25, hour: 9, minute: 30, timeZoneIdentifier: zone)
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
