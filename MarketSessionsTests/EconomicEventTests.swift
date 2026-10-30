import AppKit
import XCTest
@testable import MarketSessions

final class EconomicEventTests: XCTestCase {
    func testCompactEventLabelsPreserveFullDescriptions() {
        XCTAssertEqual(EconomicEventKind.employment.compactTitle, "U.S. Jobs Report")
        XCTAssertEqual(EconomicEventKind.fomc.compactTitle, "FOMC Decision")
        XCTAssertEqual(EconomicEventKind.fomc.title, "FOMC decision + press conference")
        XCTAssertEqual(EconomicEventKind.gdp.compactTitle, "U.S. GDP (Advance)")
        XCTAssertTrue(EconomicEventKind.allCases.allSatisfy { $0.compactTitle.count <= 30 })
    }

    func testCompactSpeechLabelPreservesTheSpecificEventName() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let speech = EconomicEvent(
            id: "speech", kind: .fedSpeech, title: "Congressional testimony",
            start: now, end: now.addingTimeInterval(60), canonicalTimeZoneIdentifier: "UTC"
        )
        XCTAssertEqual(speech.compactTitle, "Congressional testimony")
    }

    /// Not normalized: tooltips and Settings keep the system clock's narrow space before AM/PM.
    func testEventDateTimeUsesTheSystemClockSpacing() throws {
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let date = try makeDate(year: 2027, month: 3, day: 17, hour: 23, minute: 0, timeZone: newYork)
        XCTAssertEqual(
            MarketDateFormatting.dateTime(date, dateStyle: .medium, timeZone: newYork, locale: Locale(identifier: "en_US")),
            "Mar 17, 2027 at 11:00\u{202F}PM"
        )
    }

    func testBundledCatalogContainsTheTierOneKinds() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))

        XCTAssertEqual(events.count, 97)
        XCTAssertEqual(Set(events.map(\.kind)), Set(EconomicEventKind.allCases))
        XCTAssertEqual(events.filter { $0.kind == .fomc }.count, 16)
        XCTAssertEqual(events.filter { $0.kind == .cpi }.count, 12)
        XCTAssertEqual(events.filter { $0.kind == .employment }.count, 12)
        XCTAssertEqual(events.filter { $0.kind == .pce }.count, 13)
        XCTAssertEqual(events.filter { $0.kind == .retailSales }.count, 13)
        XCTAssertEqual(events.filter { $0.kind == .fedSpeech }.count, 1)
        XCTAssertEqual(events.filter { $0.kind == .fomcMinutes }.count, 3)
        XCTAssertEqual(events.filter { $0.kind == .gdp }.count, 1)
        XCTAssertEqual(events.filter { $0.kind == .ecb }.count, 11)
        XCTAssertEqual(events.filter { $0.kind == .boj }.count, 11)
        XCTAssertEqual(events.filter { $0.kind == .ppi }.count, 4)
        XCTAssertEqual(Set(events.map(\.id)).count, events.count)
    }

    func testBundled2027CentralBankDecisionsAreCompleteAndOnWeekdays() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let next = events.filter { calendar.component(.year, from: $0.start) == 2027 }

        XCTAssertEqual(next.filter { $0.kind == .fomc }.count, 8)
        XCTAssertEqual(next.filter { $0.kind == .ecb }.count, 8)
        XCTAssertEqual(next.filter { $0.kind == .boj }.count, 8)
        XCTAssertEqual(next.count, 24, "Only published central-bank calendars exist for 2027")
        for event in next {
            let weekday = calendar.component(.weekday, from: event.start)
            XCTAssertTrue((2...6).contains(weekday), "\(event.id) falls on a weekend")
        }
    }

    /// A popover row is 340pt minus 14pt margins, minus 26pt of HStack spacing and
    /// spacer, minus the widest label inside 24 hours ("Tomorrow 12:00 PM", 13pt
    /// semibold). Every bundled title must fit the rest at 13pt without truncating.
    func testEveryRowTitleFitsBesideTheWidestImminentLabel() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let label = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        let budget = 340 - 28 - 26 - ("Tomorrow 12:00\u{202F}PM" as NSString).size(withAttributes: [.font: label]).width
        let titles = Set(events.map(\.compactTitle) + EconomicEventKind.allCases.map(\.compactTitle))
        for title in titles {
            let width = (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width
            XCTAssertLessThanOrEqual(width, budget, "\(title) truncates in the popover")
        }
    }

    func testJacksonHoleKeynoteIsBundledWithItsOwnTitle() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let keynote = try XCTUnwrap(events.first { $0.kind == .fedSpeech })
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork

        XCTAssertEqual(keynote.displayTitle, "Jackson Hole Keynote")
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: keynote.start),
                       DateComponents(year: 2026, month: 8, day: 28, hour: 10, minute: 0))
    }

    func testCoverageGapNamesTheCategoryThatRunsOutBeforeTheLastShownRow() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let usYear = calendar.component(
            .year, from: try XCTUnwrap(events.filter { $0.kind.category == .usRelease }.map(\.start).max())
        )
        let resolver = UpcomingEconomicEventResolver()

        // Mid-December 2027: U.S. releases ran out earlier; only central banks remain.
        // Coverage runs through the last bundled year, not the last bundled release.
        let late = try makeDate(year: 2027, month: 12, day: 15, hour: 12, minute: 0, timeZone: newYork)
        let lateGap = try XCTUnwrap(resolver.resolve(events, at: late).coverageGap(shownCount: 4))
        XCTAssertEqual(lateGap.category, .usRelease)
        XCTAssertEqual(lateGap.end, try makeDate(year: usYear, month: 12, day: 31, hour: 23, minute: 59, timeZone: utc))

        // Late September 2026: four shown rows all fall inside every category's coverage.
        let now = try makeDate(year: 2026, month: 9, day: 29, hour: 12, minute: 0, timeZone: newYork)
        XCTAssertNil(resolver.resolve(events, at: now).coverageGap(shownCount: 4))

        // Central banks only: U.S. coverage is irrelevant and never reported.
        let banks = resolver.resolve(events, at: late, enabledKinds: [.ecb, .boj])
        XCTAssertNil(banks.coverageEnds[.usRelease])
    }

    func testCoverageFollowsTheSelectedKindThatRunsOutFirst() throws {
        let events = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let resolver = UpcomingEconomicEventResolver()
        let now = try makeDate(year: 2026, month: 12, day: 15, hour: 12, minute: 0, timeZone: newYork)

        // FOMC decisions are bundled into 2027, minutes only through 2026: the rows past
        // New Year are missing their minutes, so the line names 2026.
        let gap = try XCTUnwrap(
            resolver.resolve(events, at: now, enabledKinds: [.fomc, .fomcMinutes]).coverageGap(shownCount: 4)
        )
        XCTAssertEqual(gap.category, .centralBank)
        XCTAssertEqual(gap.end, try makeDate(year: 2026, month: 12, day: 31, hour: 23, minute: 59, timeZone: utc))

        // Fed Chair appearances have no published calendar: few or no rows, but no line.
        for date in [now, try makeDate(year: 2027, month: 6, day: 1, hour: 12, minute: 0, timeZone: newYork)] {
            XCTAssertNil(resolver.resolve(events, at: date, enabledKinds: [.fedSpeech]).coverageGap(shownCount: 4))
        }
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
        // reaches ahead to the five-event minimum and no further.
        XCTAssertEqual(snapshot.events.map(\.id), ["nearby", "far-0", "far-1", "far-2", "far-3"])
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

/// Weekly updates from official pages. Fixtures are trimmed copies of the pages as
/// served on 2026-10-29; no test reaches the network.
final class LiveEventTests: XCTestCase {
    func testFedMeetingsReadSecondDaysAcrossMonthsAndSkipNotationVotes() {
        let page = """
        <div class="panel panel-default"><div class="panel-heading"><h4><a id="45694">2027 FOMC Meetings</a></h4></div>
            <div class="fomc-meeting__month col-xs-5 col-sm-3 col-md-2"><strong>January</strong></div>

            <div class="fomc-meeting__date col-xs-4 col-sm-9 col-md-10 col-lg-1">26-27</div>
            <div class="fomc-meeting--shaded fomc-meeting__month col-xs-5 col-sm-3 col-md-2"><strong>March</strong></div>
            <div class="fomc-meeting__date col-xs-4 col-sm-9 col-md-10 col-lg-1">16-17*</div>
        <div class="panel panel-default"><div class="panel-heading"><h4><a id="36495">2023 FOMC Meetings</a></h4></div>
            <div class="fomc-meeting__month col-xs-5 col-sm-3 col-md-2"><strong>Jan/Feb</strong></div>

            <div class="fomc-meeting__date col-xs-4 col-sm-9 col-md-10 col-lg-1">31-1</div>
            <div class="fomc-meeting__month col-xs-5 col-sm-3 col-md-2"><strong>August</strong></div>
            <div class="fomc-meeting__date col-xs-4 col-sm-9 col-md-10 col-lg-2">22 (notation vote)</div>
        """
        let rows = LiveEventParser.fomcMeetings(page)
        XCTAssertEqual(rows.map(\.id), ["2027-01-27-fomc", "2027-03-17-fomc", "2023-02-01-fomc"])
        XCTAssertEqual(rows.first?.time, "14:00")
        XCTAssertEqual(rows.first?.durationMinutes, 90)
    }

    func testFedMinutesComeFromTheMonthlyCalendarPage() {
        let page = """
            <title>Federal Reserve Board - Calendar: November 2026 </title>
                                <div class="col-xs-2">
                                    <p>2:00 p.m.</p>
                                </div>
                                <div class="col-xs-7">
                                    <p>FOMC Minutes</p>
                                    <p><p>Meeting of October 27-28</p></p>
                                </div>
                                <div class="col-xs-3">
                                    <p>18</p>
                                </div>
        """
        XCTAssertEqual(LiveEventParser.fomcMinutes(page).map(\.id), ["2026-11-18-fomc-minutes"])
    }

    func testPersonalIncomeKeepsBEAsOwnTimesInNewYork() throws {
        let data = Data("""
        {"Gross Domestic Product": {"release_dates": ["2026-10-29T12:30:00+00:00"]},
         "Personal Income and Outlays": {"release_dates": ["2026-01-22T15:00:00+00:00", "2026-12-23T13:30:00+00:00"]},
         "file_last_updated": "2026-10-22T14:01:12.123456"}
        """.utf8)
        let rows = LiveEventParser.personalIncome(data)
        XCTAssertEqual(rows.map(\.id), ["2026-01-22-pce", "2026-12-23-pce"])
        XCTAssertEqual(rows.map(\.time), ["10:00", "08:30"])
    }

    func testRetailSalesReadOnlyTheAdvanceTable() {
        let page = """
        <td style="text-align:center"><strong>Release Date at 8:30 am</strong></td>
        <td style="text-align:center">September 2026</td>
        <td style="text-align:center">October 15, 2026</td>
        <td style="text-align:center">December 2026</td>
        <td style="text-align:center">January 15, 2027</td>
        </tbody></table>
        <td style="text-align:center"><strong>Release Date at 8:30 am for sales and<br />
        <td style="text-align:center">March 2, 2027</td>
        """
        XCTAssertEqual(LiveEventParser.retailSales(page).map(\.id), ["2026-10-15-retail-sales", "2027-01-15-retail-sales"])
    }

    func testECBDecisionsAreTheSecondMeetingDays() {
        let page = """
        <dt>
        28/10/2026
        </dt>
        <dd>
        Governing Council of the ECB: monetary policy meeting in Frankfurt (Day 1)<br>
        </dd>
        <dt>
        29/10/2026
        </dt>
        <dd>
        Governing Council of the ECB: monetary policy meeting in Frankfurt (Day 2), followed by press conference<br>
        </dd>
        <dt>
        12/11/2026
        </dt>
        <dd>
        Governing Council of the ECB: non-monetary policy meeting<br>
        </dd>
        """
        let rows = LiveEventParser.ecb(page)
        XCTAssertEqual(rows.map(\.id), ["2026-10-29-ecb"])
        XCTAssertEqual(rows.first?.timeZone, "Europe/Berlin")
    }

    func testBOJMeetingsReadAcrossLineBreaksAndMonths() {
        let page = """
        <caption class="non-caption">Table : 2027</caption>
        <tbody>
        <tr>
          <td>Jan. 21 (Thurs.), 22 (Fri.)</td>
          <td>Jan. 22 (Fri.)</td>
         </tr>
         <tr>
          <td>Sept. 21
          (Tues.), 22 (Wed.)</td>
          <td>-</td>
         </tr>
         <tr>
          <td>Apr. 30 (Fri.), May 1 (Sat.)</td>
         </tr>
        </tbody>
        </table>
        """
        XCTAssertEqual(LiveEventParser.boj(page).map(\.id), ["2027-01-22-boj", "2027-09-22-boj", "2027-05-01-boj"])

        // Meetings already held link to their statement PDF.
        let held = """
        <caption class="non-caption">Table : 2026</caption>
        <tr>
          <td><a href="/en/mopo/mpmdeci/mpr_2026/k260123a.pdf">Jan. 22 (Thurs.), 23 (Fri.) <span class="adjust-pdf">[PDF 171KB]</span></a></td>
        </tr>
        </table>
        """
        XCTAssertEqual(LiveEventParser.boj(held).map(\.id), ["2026-01-23-boj"])
    }

    /// Inside its range a page replaces bundled dates, so one the parser skipped would
    /// vanish; the page counts as unread instead and the bundled date stays.
    func testAPageMissingABundledDateCountsAsUnread() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundled = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-29T16:00:00Z"))
        let cacheURL = directory.appendingPathComponent("live-events.json")
        let complete = await LiveEventRefresher(fetcher: StubFetcher(), cacheURL: cacheURL)
            .run(at: now, previous: LiveEventCache(), bundled: bundled)
        XCTAssertFalse(complete.failures.contains(.fedMeetings))

        let missing = await LiveEventRefresher(fetcher: StubFetcher(droppedMeeting: "June"), cacheURL: cacheURL)
            .run(at: now, previous: LiveEventCache(), bundled: bundled)
        XCTAssertTrue(missing.failures.contains(.fedMeetings))
        XCTAssertTrue(missing.merged(into: bundled).contains { $0.id == "2027-06-09-fomc" })
    }

    func testFetchedDatesReplaceBundledOnesOnlyInsideTheirRange() throws {
        let bundled = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let moved = BundledEvent(id: "2026-12-18-ecb", kind: .ecb, title: nil, date: "2026-12-18",
                                 time: "14:15", durationMinutes: 90, timeZone: "Europe/Berlin")
        let cache = LiveEventCache(attemptedAt: Date(), results: [LiveSourceResult(
            source: .ecb, events: [moved],
            ranges: [.init(first: "2026-12-01", last: "2026-12-31")]
        )])
        let merged = cache.merged(into: bundled).filter { $0.kind == .ecb }.map(\.id)
        XCTAssertTrue(merged.contains("2026-12-18-ecb"))
        XCTAssertFalse(merged.contains("2026-12-17-ecb"), "The bundled December date is replaced")
        XCTAssertTrue(merged.contains("2027-02-04-ecb"), "Dates outside the fetched range stay bundled")
    }

    func testAFailingSourceKeepsItsLastResultAndRetriesDaily() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let refresher = LiveEventRefresher(
            fetcher: StubFetcher(),
            cacheURL: directory.appendingPathComponent("live-events.json")
        )
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-29T16:00:00Z"))
        let old = LiveSourceResult(source: .ecb, events: [], ranges: [])
        let bundled = try EconomicEventCatalog.loadAll(bundle: Bundle(for: Self.self))
        let cache = await refresher.run(at: now, previous: LiveEventCache(results: [old]), bundled: bundled)

        XCTAssertEqual(Set(cache.failures), [.ecb, .boj, .censusRetail, .beaPersonalIncome])
        XCTAssertEqual(cache.results.first { $0.source == .ecb }, old, "The 403 keeps the earlier result")
        XCTAssertEqual(cache.results.first { $0.source == .fedMinutes }?.events.map(\.id), ["2026-11-19-fomc-minutes"],
                       "Not-yet-published months (404) are skipped, not failures")
        XCTAssertEqual(refresher.loadCache(), cache, "Saved to disk")
        XCTAssertFalse(cache.isDue(at: now.addingTimeInterval(3_600)))
        XCTAssertTrue(cache.isDue(at: now.addingTimeInterval(86_400)), "Daily while a source fails")
        XCTAssertFalse(LiveEventCache(attemptedAt: now).isDue(at: now.addingTimeInterval(6 * 86_400)))
        XCTAssertTrue(LiveEventCache(attemptedAt: now).isDue(at: now.addingTimeInterval(7 * 86_400)))
    }

    @MainActor
    func testModelUsesFetchedDatesOnlyWhileUpdatesAreOn() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "MarketSessionsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-29T16:00:00Z"))
        let model = MarketSessionsModel(
            loginItemService: LiveLoginItemStub(),
            notificationCenter: LiveNotificationCenterStub(),
            liveEvents: LiveEventRefresher(fetcher: StubFetcher(), cacheURL: directory.appendingPathComponent("live.json")),
            nowProvider: { now },
            preferencesStore: defaults
        )
        await model.liveEventUpdate?.value
        XCTAssertEqual(model.nextEvent(of: .fomcMinutes)?.id, "2026-11-19-fomc-minutes", "The fetched date wins")
        XCTAssertNotNil(model.liveEventCache?.attemptedAt)

        model.setRefreshesEventDates(false)
        XCTAssertFalse(MarketPreferences(defaults: defaults).refreshesEventDates)
        XCTAssertEqual(model.nextEvent(of: .fomcMinutes)?.id, "2026-11-18-fomc-minutes", "Off means bundled dates only")
    }
}

extension LiveEventTests {
    /// Fetched PCE dates run into 2027, but CPI, jobs and PPI are bundled only through
    /// 2026, so Settings must not claim U.S. release dates run through 2027.
    @MainActor
    func testCoverageFollowsTheKindThatEndsFirst() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cacheURL = directory.appendingPathComponent("live.json")
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-29T16:00:00Z"))
        let pce = BundledEvent(id: "2027-06-25-pce", kind: .pce, title: nil, date: "2027-06-25",
                               time: "08:30", durationMinutes: 1, timeZone: "America/New_York")
        let cache = LiveEventCache(attemptedAt: now, results: [LiveSourceResult(
            source: .beaPersonalIncome, events: [pce],
            ranges: [.init(first: "2027-06-25", last: "2027-06-25")]
        )])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(cache).write(to: cacheURL)
        let model = MarketSessionsModel(
            loginItemService: LiveLoginItemStub(),
            notificationCenter: LiveNotificationCenterStub(),
            liveEvents: LiveEventRefresher(fetcher: StubFetcher(), cacheURL: cacheURL),
            nowProvider: { now }
        )
        XCTAssertNil(model.liveEventUpdate, "A fresh cache is not refetched")
        let usEnd = try XCTUnwrap(model.eventScheduleEnd(for: .usRelease))
        XCTAssertLessThan(usEnd, try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z")))
    }
}

/// The Fed answers; November's minutes page lists Nov 19 (bundled: Nov 18) and later months are not
/// published; ECB returns 403; BOJ, BEA and Census fail to connect.
private struct StubFetcher: EventFetching {
    /// A 2027 FOMC month left off the calendar page, as if the parser skipped its row.
    var droppedMeeting: String?

    func fetch(_ url: URL) async throws -> (Data, Int) {
        switch url.absoluteString {
        case let path where path.hasSuffix("2026-october.htm"):
            return (Data("<title>Calendar: October 2026 </title>".utf8), 200)
        case let path where path.hasSuffix("2026-november.htm"):
            return (Data("""
            <title>Federal Reserve Board - Calendar: November 2026 </title>
            <p>FOMC Minutes</p>
            </div>
            <div class="col-xs-3">
                <p>19</p>
            """.utf8), 200)
        case let path where path.contains("/newsevents/"):
            return (Data(), 404)
        case let path where path.hasSuffix("fomccalendars.htm"):
            // The bundled 2027 meetings, less any the test drops.
            let meetings = [("January", "26-27"), ("March", "16-17"), ("April", "27-28"), ("June", "8-9"),
                            ("July", "27-28"), ("September", "14-15"), ("October", "26-27"), ("December", "7-8")]
            let rows = meetings.filter { $0.0 != droppedMeeting }.map { month, days in
                """
                <div class="fomc-meeting__month"><strong>\(month)</strong></div>
                <div class="fomc-meeting__date">\(days)</div>
                """
            }.joined()
            return (Data("<h4><a id=\"1\">2027 FOMC Meetings</a></h4>\(rows)".utf8), 200)
        case let path where path.contains("ecb.europa.eu"):
            return (Data("Access Denied".utf8), 403)
        default:
            throw URLError(.cannotConnectToHost)
        }
    }
}

@MainActor
private final class LiveLoginItemStub: LoginItemServicing {
    var state: LoginItemState = .disabled
    func setEnabled(_ enabled: Bool) throws { state = enabled ? .enabled : .disabled }
}

@MainActor
private final class LiveNotificationCenterStub: NotificationCentering {
    func activate() {}
    func authorizationStatus() async -> NotificationAuthorizationState { .notDetermined }
    func requestAuthorization() async -> NotificationAuthorizationState { .notDetermined }
    func add(_ notifications: [PlannedNotification]) async -> Set<String> { [] }
    func removePending(identifiers: [String]) {}
    func removeAllPending() {}
}
