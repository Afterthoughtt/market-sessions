import XCTest
@testable import MarketSessions

final class EconomicEventTests: XCTestCase {
    func testBundledCatalogContainsTheTierOneKinds() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))

        XCTAssertEqual(events.count, 73)
        XCTAssertEqual(Set(events.map(\.kind)), Set(EconomicEventKind.allCases))
        XCTAssertEqual(events.filter { $0.kind == .fomc }.count, 8)
        XCTAssertEqual(events.filter { $0.kind == .cpi }.count, 12)
        XCTAssertEqual(events.filter { $0.kind == .employment }.count, 12)
        XCTAssertEqual(events.filter { $0.kind == .pce }.count, 13)
        XCTAssertEqual(events.filter { $0.kind == .retailSales }.count, 13)
        XCTAssertEqual(events.filter { $0.kind == .fedSpeech }.count, 1)
        XCTAssertEqual(events.filter { $0.kind == .fomcMinutes }.count, 3)
        XCTAssertEqual(events.filter { $0.kind == .gdp }.count, 1)
        XCTAssertEqual(events.filter { $0.kind == .ecb }.count, 3)
        XCTAssertEqual(events.filter { $0.kind == .boj }.count, 3)
        XCTAssertEqual(events.filter { $0.kind == .ppi }.count, 4)
        XCTAssertEqual(Set(events.map(\.id)).count, events.count)
    }

    func testJacksonHoleKeynoteIsBundledWithItsOwnTitle() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let keynote = try XCTUnwrap(events.first { $0.kind == .fedSpeech })
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork

        XCTAssertEqual(keynote.displayTitle, "Jackson Hole keynote — Fed Chair")
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: keynote.start),
                       DateComponents(year: 2026, month: 8, day: 28, hour: 10, minute: 0))
    }

    func testScheduleEndSurfacesWhenTheCatalogIsNearlyExhausted() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        // Mid-December: fewer than four events remain in the 2026 catalog.
        let now = try makeDate(year: 2026, month: 12, day: 17, hour: 12, minute: 0, timeZone: newYork)

        let snapshot = UpcomingEconomicEventResolver().resolve(events, at: now)

        XCTAssertLessThan(snapshot.events.count, 4)
        let scheduleEnd = try XCTUnwrap(snapshot.scheduleEnd)
        XCTAssertEqual(scheduleEnd, events.map(\.end).max())
    }

    func testUpcomingEventsAreNeverEmptyWhileTheCatalogHasFutureEvents() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let vancouver = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        // Thursday after this week's only event (PCE, Aug 26) has passed.
        let now = try makeDate(
            year: 2026,
            month: 8,
            day: 27,
            hour: 11,
            minute: 0,
            timeZone: vancouver
        )

        let snapshot = UpcomingEconomicEventResolver().resolve(events, at: now)

        // The 14-day horizon is quiet-ish, so the resolver reaches ahead to at least four.
        XCTAssertGreaterThanOrEqual(snapshot.events.count, 4)
        XCTAssertEqual(snapshot.events.first?.id, "2026-08-28-fedspeech-jackson-hole")
        XCTAssertTrue(snapshot.events.allSatisfy { $0.end > now })
        let starts = snapshot.events.map(\.start)
        XCTAssertEqual(starts, starts.sorted())
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

    func testUpcomingResolverDropsPastEventsAndRespectsTheHorizon() throws {
        let vancouver = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let now = try makeDate(
            year: 2026,
            month: 8,
            day: 24,
            hour: 12,
            minute: 0,
            timeZone: vancouver
        )
        let past = try makeEvent(id: "past", year: 2026, month: 8, day: 21, timeZone: vancouver)
        let nearby = try makeEvent(id: "nearby", year: 2026, month: 8, day: 28, timeZone: vancouver)
        let farOut = (0..<5).map { index in
            EconomicEvent(
                id: "far-\(index)",
                kind: .cpi,
                title: nil,
                start: now.addingTimeInterval(TimeInterval(30 + index) * 86_400),
                end: now.addingTimeInterval(TimeInterval(30 + index) * 86_400 + 60),
                canonicalTimeZoneIdentifier: vancouver.identifier
            )
        }

        let snapshot = UpcomingEconomicEventResolver().resolve(
            [past, nearby] + farOut,
            at: now
        )

        // The past event is gone; the horizon holds one event, so the resolver
        // reaches ahead to the four-event minimum and no further.
        XCTAssertEqual(snapshot.events.map(\.id), ["nearby", "far-0", "far-1", "far-2"])
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
            title: nil,
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
