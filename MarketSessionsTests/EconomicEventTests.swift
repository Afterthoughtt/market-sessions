import XCTest
@testable import MarketSessions

final class EconomicEventTests: XCTestCase {
    func testBundledCatalogContainsOnlyTheFiveTierOneKinds() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))

        XCTAssertEqual(events.count, 58)
        XCTAssertEqual(Set(events.map(\.kind)), Set(EconomicEventKind.allCases))
        XCTAssertEqual(events.filter { $0.kind == .fomc }.count, 8)
        XCTAssertEqual(events.filter { $0.kind == .cpi }.count, 12)
        XCTAssertEqual(events.filter { $0.kind == .employment }.count, 12)
        XCTAssertEqual(events.filter { $0.kind == .pce }.count, 13)
        XCTAssertEqual(events.filter { $0.kind == .retailSales }.count, 13)
        XCTAssertEqual(Set(events.map(\.id)).count, events.count)
    }

    func testCurrentWeekFiltersMondayThroughFridayAndFindsTheNextEvent() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let vancouver = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let now = try makeDate(
            year: 2026,
            month: 8,
            day: 25,
            hour: 11,
            minute: 0,
            timeZone: vancouver
        )

        let snapshot = WeeklyEconomicEventResolver().resolve(
            events,
            weekContaining: now,
            displayTimeZone: vancouver
        )

        XCTAssertEqual(snapshot.events.map(\.id), ["2026-08-26-pce"])
        XCTAssertEqual(snapshot.nextEventID, "2026-08-26-pce")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = vancouver
        let event = try XCTUnwrap(snapshot.events.first)
        XCTAssertEqual(calendar.component(.hour, from: event.start), 5)
        XCTAssertEqual(calendar.component(.minute, from: event.start), 30)
    }

    func testUSReleasesKeepTheirCanonicalNewYorkTime() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let september = try XCTUnwrap(events.first { $0.id == "2026-09-11-cpi" })
        let november = try XCTUnwrap(events.first { $0.id == "2026-11-10-cpi" })

        XCTAssertEqual(september.canonicalTimeZoneIdentifier, "America/New_York")
        XCTAssertEqual(november.canonicalTimeZoneIdentifier, "America/New_York")
        XCTAssertEqual(calendar.component(.hour, from: september.start), 8)
        XCTAssertEqual(calendar.component(.minute, from: september.start), 30)
        XCTAssertEqual(calendar.component(.hour, from: november.start), 8)
        XCTAssertEqual(calendar.component(.minute, from: november.start), 30)
    }

    func testFOMCDecisionAndPressConferenceAreOneExtendedWindow() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let event = try XCTUnwrap(events.first { $0.id == "2026-09-16-fomc" })
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let duringPressConference = try makeDate(
            year: 2026,
            month: 9,
            day: 16,
            hour: 14,
            minute: 45,
            timeZone: newYork
        )

        XCTAssertEqual(event.end.timeIntervalSince(event.start), 90 * 60)
        XCTAssertEqual(event.phase(at: duringPressConference), .live)
        XCTAssertEqual(event.remainingMinutes(at: duringPressConference), 45)
        XCTAssertEqual(event.phase(at: event.end), .past)
        XCTAssertNil(event.remainingMinutes(at: event.end))
    }

    func testWeekResolverExcludesWeekendEvents() throws {
        let vancouver = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let friday = try makeEvent(
            id: "friday",
            year: 2026,
            month: 8,
            day: 28,
            timeZone: vancouver
        )
        let saturday = try makeEvent(
            id: "saturday",
            year: 2026,
            month: 8,
            day: 29,
            timeZone: vancouver
        )
        let now = try makeDate(
            year: 2026,
            month: 8,
            day: 24,
            hour: 12,
            minute: 0,
            timeZone: vancouver
        )

        let snapshot = WeeklyEconomicEventResolver().resolve(
            [friday, saturday],
            weekContaining: now,
            displayTimeZone: vancouver
        )

        XCTAssertEqual(snapshot.events.map(\.id), ["friday"])
    }

    func testInvalidBundledDateIsRejected() {
        let data = Data(
            """
            {"events":[{"id":"bad","kind":"cpi","date":"2026-02-30","time":"08:30","durationMinutes":1,"timeZone":"America/New_York"}]}
            """.utf8
        )

        XCTAssertThrowsError(try EconomicEventCatalog.decode(data)) { error in
            XCTAssertEqual(error as? EconomicEventCatalogError, .invalidDate("2026-02-30"))
        }
    }

    private func makeEvent(
        id: String,
        year: Int,
        month: Int,
        day: Int,
        timeZone: TimeZone
    ) throws -> EconomicEvent {
        let start = try makeDate(
            year: year,
            month: month,
            day: day,
            hour: 8,
            minute: 30,
            timeZone: timeZone
        )
        return EconomicEvent(
            id: id,
            kind: .cpi,
            start: start,
            end: start.addingTimeInterval(60),
            canonicalTimeZoneIdentifier: timeZone.identifier
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZone: TimeZone
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}
