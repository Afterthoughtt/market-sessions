import AppKit
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

    /// The approved mock: Wednesday before Thanksgiving, 5:30 PM in New York.
    func testClosuresListTheComingWeekButNotToday() throws {
        let index = try MarketExceptionCatalog.loadIndex(bundle: Bundle(for: Self.self))
        let zone = "America/New_York"
        let now = try makeDate(year: 2026, month: 11, day: 25, hour: 17, minute: 30, timeZone: zone)
        let newYork = try XCTUnwrap(TimeZone(identifier: zone))
        let sessions = [MarketScheduleCatalog.session(.newYorkCash), MarketScheduleCatalog.session(.cmeFutures)]
        let result = UpcomingClosureResolver().resolve(index, sessions: sessions, at: now, displayTimeZone: newYork)

        XCTAssertEqual(result.closures.map(\.id), [
            "newYorkCash-2026-11-26", "cmeFutures-2026-11-26", "newYorkCash-2026-11-27", "cmeFutures-2026-11-27",
        ])
        XCTAssertEqual(result.closures.first?.exception.name, "Thanksgiving")
        // Holidays sort from the start of their own day; early closes at the close.
        XCTAssertEqual(result.closures[1].date, try makeDate(year: 2026, month: 11, day: 26, hour: 13, minute: 0, timeZone: zone))
        XCTAssertFalse(result.passesCoverage)

        // On Thanksgiving itself the holiday is today's Holiday section, not a closure row.
        let thanksgiving = try makeDate(year: 2026, month: 11, day: 26, hour: 10, minute: 0, timeZone: zone)
        XCTAssertFalse(UpcomingClosureResolver().resolve(index, sessions: sessions, at: thanksgiving, displayTimeZone: newYork)
            .closures.contains { $0.id == "newYorkCash-2026-11-26" })
    }

    /// Black Friday: before New York opens its row reads "Opens", so the 1:00 PM early
    /// close stays in Closures; once open, the row shows it and Closures drops it.
    @MainActor
    func testTodaysEarlyCloseListsUntilTheRowShowsIt() throws {
        let index = try MarketExceptionCatalog.loadIndex(bundle: Bundle(for: Self.self))
        let zone = "America/New_York"
        let newYork = try XCTUnwrap(TimeZone(identifier: zone))
        let sessions = [MarketScheduleCatalog.session(.newYorkCash)]
        let early = try makeDate(year: 2026, month: 11, day: 27, hour: 8, minute: 0, timeZone: zone)
        XCTAssertEqual(UpcomingClosureResolver().resolve(index, sessions: sessions, at: early, displayTimeZone: newYork)
            .closures.first?.id, "newYorkCash-2026-11-27")
        let afterClose = try makeDate(year: 2026, month: 11, day: 27, hour: 14, minute: 0, timeZone: zone)
        XCTAssertFalse(UpcomingClosureResolver().resolve(index, sessions: sessions, at: afterClose, displayTimeZone: newYork)
            .closures.contains { $0.id == "newYorkCash-2026-11-27" })

        func model(at date: Date) -> MarketSessionsModel {
            MarketSessionsModel(
                loginItemService: ClosureLoginItemStub(),
                nowProvider: { date },
                displayTimeZoneProvider: { newYork }
            )
        }
        XCTAssertTrue(model(at: early).upcomingClosures.closures.contains { $0.id == "newYorkCash-2026-11-27" })
        let open = try makeDate(year: 2026, month: 11, day: 27, hour: 10, minute: 0, timeZone: zone)
        XCTAssertFalse(model(at: open).upcomingClosures.closures.contains { $0.id == "newYorkCash-2026-11-27" })
    }

    func testClosuresUseEachMarketsOwnDayAndFlagMissingCoverage() throws {
        let index = try MarketExceptionCatalog.loadIndex(bundle: Bundle(for: Self.self))
        // Wed Dec 30 noon in New York is 5 PM in London but already Thu Dec 31 in Tokyo,
        // so Tokyo's year-end holiday is today there while London's half day is still ahead.
        let now = try makeDate(year: 2026, month: 12, day: 30, hour: 12, minute: 0, timeZone: "America/New_York")
        let result = UpcomingClosureResolver().resolve(
            index, sessions: [MarketScheduleCatalog.session(.tokyo), MarketScheduleCatalog.session(.london)], at: now,
            displayTimeZone: try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        )
        XCTAssertEqual(result.closures.map(\.id), ["london-2026-12-31"])
        XCTAssertTrue(result.passesCoverage, "The week runs past Dec 31, where the bundled data ends")
    }

    /// Christmas week in New York: Hong Kong's Dec 25 holiday starts on Dec 24 in New York
    /// but still lists after the Dec 24 early closes, by the day each row shows.
    func testClosuresSortByTheDayTheyShow() throws {
        let index = try MarketExceptionCatalog.loadIndex(bundle: Bundle(for: Self.self))
        let now = try makeDate(year: 2026, month: 12, day: 22, hour: 19, minute: 0, timeZone: "America/New_York")
        let result = UpcomingClosureResolver().resolve(
            index, sessions: MarketScheduleCatalog.sessions, at: now,
            displayTimeZone: try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        )
        XCTAssertEqual(result.closures.map(\.id), [
            "hongKong-2026-12-24", "london-2026-12-24", "newYorkCash-2026-12-24", "cmeFutures-2026-12-24",
            "newYorkCash-2026-12-25", "cmeFutures-2026-12-25", "london-2026-12-25", "hongKong-2026-12-25",
            "london-2026-12-28",
        ])
    }

    func testCloseShownIsFlaggedEarlyOnlyAtABundledEarlyClose() throws {
        let zone = "America/New_York"
        let resolver = try bundledResolver()
        let newYork = MarketScheduleCatalog.session(.newYorkCash)
        let cme = MarketScheduleCatalog.session(.cmeFutures)
        // Wednesday evening after CME's maintenance hour: its session runs to Thursday's 12:00 CT halt.
        let wednesday = try makeDate(year: 2026, month: 11, day: 25, hour: 19, minute: 0, timeZone: zone)
        XCTAssertTrue(resolver.resolve(cme, at: wednesday).closesEarly)
        XCTAssertFalse(resolver.resolve(newYork, at: wednesday).closesEarly, "After Hours shows an open, not a close")

        let friday = try makeDate(year: 2026, month: 11, day: 27, hour: 10, minute: 0, timeZone: zone)
        XCTAssertTrue(resolver.resolve(newYork, at: friday).closesEarly)
        let regular = try makeDate(year: 2026, month: 11, day: 24, hour: 10, minute: 0, timeZone: zone)
        XCTAssertFalse(resolver.resolve(newYork, at: regular).closesEarly)
    }

    /// Closure rows share the event rows' 24pt layout beside the widest date ("Wed, Sep 30").
    func testEveryHolidayNameFitsAClosureRow() throws {
        let index = try MarketExceptionCatalog.loadIndex(bundle: Bundle(for: Self.self))
        let font = NSFont.systemFont(ofSize: 13)
        let budget = 340 - 28 - 26 - ("Wed, Sep 30" as NSString).size(withAttributes: [.font: font]).width
        for exception in index.all where exception.kind == .holiday {
            let name = try XCTUnwrap(exception.name, "\(exception.dateKey) needs a name")
            let session = MarketScheduleCatalog.session(exception.market)
            let width = ("\(session.name) · \(name)" as NSString).size(withAttributes: [.font: font]).width
            XCTAssertLessThanOrEqual(width, budget, "\(name) truncates in the popover")
        }
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

        XCTAssertEqual(result.status, .holiday)
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

        XCTAssertEqual(result.status, .holiday)
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

        XCTAssertEqual(result.status, .holiday)
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

@MainActor
private final class ClosureLoginItemStub: LoginItemServicing {
    var state: LoginItemState = .disabled
    func setEnabled(_ enabled: Bool) throws { state = enabled ? .enabled : .disabled }
}
