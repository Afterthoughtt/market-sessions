import XCTest
@testable import MarketSessions

final class ProgressTests: XCTestCase {
    func testTransitionTimeShowsTheDateAWeekOrMoreOut() {
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        let now = ISO8601DateFormatter().date(from: "2026-09-30T07:48:00Z")!  // Wed 12:48 AM PDT
        let enUS = Locale(identifier: "en_US")
        let tomorrow = ISO8601DateFormatter().date(from: "2026-10-01T01:30:00Z")!  // Wed 6:30 PM PDT
        let nextWeek = ISO8601DateFormatter().date(from: "2026-10-08T01:30:00Z")!  // Wed Oct 7 6:30 PM PDT
        XCTAssertEqual(
            MarketDateFormatting.transitionTime(tomorrow, relativeTo: now, timeZone: zone, locale: enUS),
            "6:30\u{202F}PM"
        )
        XCTAssertEqual(
            MarketDateFormatting.transitionTime(nextWeek, relativeTo: now, timeZone: zone, locale: enUS),
            "Oct 7 6:30\u{202F}PM"
        )
    }

    func testCompactDurationFormatting() {
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 348), "5h 48m")
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 45), "45m")
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 120), "2h")
        // Days drop the minutes component: 1d 3h, matching the design's "Opens in 1d 3h".
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 27 * 60 + 25), "1d 3h")
        XCTAssertEqual(MarketDurationFormatting.compact(minutes: 0), "0m")
    }

    func testSpokenDurationFormatting() {
        XCTAssertEqual(MarketDurationFormatting.spoken(minutes: 348), "5 hours, 48 minutes")
        XCTAssertEqual(MarketDurationFormatting.spoken(minutes: 27 * 60), "1 day, 3 hours")
        XCTAssertEqual(MarketDurationFormatting.spoken(minutes: 1), "1 minute")
    }

    @MainActor
    func testModelFrozenOrderRecomputesOnlyAtHandover() throws {
        let clock = MutableClock(
            date: try makeDate(
                year: 2026, month: 8, day: 28, hour: 7, minute: 12,
                timeZoneIdentifier: "America/Los_Angeles"
            )
        )
        let model = MarketSessionsModel(
            loginItemService: StubLoginItemService(),
            nowProvider: { clock.date },
            displayTimeZoneProvider: { TimeZone(identifier: "America/Los_Angeles")! }
        )

        // Friday 7:12 AM PDT — sorted by next transition.
        XCTAssertEqual(
            model.orderedSessions.map(\.session.code),
            ["LDN", "NY", "CME", "TYO", "HKG", "SHG"]
        )

        // A minute later nothing has opened or closed: the order is frozen.
        clock.date = clock.date.addingTimeInterval(60)
        model.refresh()
        XCTAssertEqual(
            model.orderedSessions.map(\.session.code),
            ["LDN", "NY", "CME", "TYO", "HKG", "SHG"]
        )

        // After London's 8:30 close the handover re-sorts; London drops to the end.
        clock.date = try makeDate(
            year: 2026, month: 8, day: 28, hour: 8, minute: 31,
            timeZoneIdentifier: "America/Los_Angeles"
        )
        model.refresh()
        XCTAssertEqual(model.orderedSessions.first?.session.code, "NY")
        XCTAssertEqual(model.orderedSessions.last?.session.code, "LDN")
    }

    @MainActor
    func testUTCDayReadout() throws {
        let clock = MutableClock(
            date: try makeDate(
                year: 2026, month: 8, day: 28, hour: 14, minute: 12,
                timeZoneIdentifier: "UTC"
            )
        )
        let model = MarketSessionsModel(
            loginItemService: StubLoginItemService(),
            nowProvider: { clock.date },
            displayTimeZoneProvider: { TimeZone(identifier: "America/Los_Angeles")! }
        )

        XCTAssertEqual(model.utcDayRemainingMinutes, 588) // 9h 48m
        XCTAssertEqual(model.utcDayRemainingFraction, 588.0 / 1_440.0, accuracy: 0.000_001)
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

private final class MutableClock: @unchecked Sendable {
    var date: Date

    init(date: Date) {
        self.date = date
    }
}

@MainActor
private final class StubLoginItemService: LoginItemServicing {
    var state: LoginItemState = .disabled

    func setEnabled(_ enabled: Bool) throws {
        state = enabled ? .enabled : .disabled
    }
}
