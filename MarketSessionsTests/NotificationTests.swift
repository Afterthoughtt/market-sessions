import XCTest
@testable import MarketSessions

final class NotificationTests: XCTestCase {
    private let posix = Locale(identifier: "en_US_POSIX")
    private let tokyoZone = TimeZone(identifier: "Asia/Tokyo")!

    // Monday 2026-08-24 08:00 JST: Tokyo trades 9:00–11:30 and 12:30–15:30.
    func testMarketsNotifyAtDailyOpenAndFinalCloseOnly() throws {
        let now = try makeDate(year: 2026, month: 8, day: 24, hour: 8, minute: 0, timeZoneIdentifier: "Asia/Tokyo")
        let planned = NotificationPlanner().plan(
            sessions: [MarketScheduleCatalog.session(.tokyo)], events: [], leadMinutes: 0,
            at: now, resolver: SessionResolver(), displayTimeZone: tokyoZone, locale: posix
        )
        let monday = planned.filter { Calendar.tokyo.isDate($0.fireDate, inSameDayAs: now) }
        XCTAssertEqual(monday.map(\.body).map(normalized), ["Opens at 9:00 AM", "Closes at 3:30 PM"])
        XCTAssertEqual(monday.map(\.title), ["Tokyo", "Tokyo"])
        XCTAssertEqual(monday.first?.fireDate, try makeDate(
            year: 2026, month: 8, day: 24, hour: 9, minute: 0, timeZoneIdentifier: "Asia/Tokyo"
        ))
        XCTAssertTrue(planned.allSatisfy { $0.fireDate > now })
        XCTAssertEqual(planned.map(\.fireDate), planned.map(\.fireDate).sorted())
        XCTAssertEqual(Set(planned.map(\.id)).count, planned.count)
    }

    func testLeadTimeMovesFireDateAndWording() throws {
        let now = try makeDate(year: 2026, month: 8, day: 24, hour: 8, minute: 0, timeZoneIdentifier: "Asia/Tokyo")
        let planned = NotificationPlanner().plan(
            sessions: [MarketScheduleCatalog.session(.tokyo)], events: [], leadMinutes: 15,
            at: now, resolver: SessionResolver(), displayTimeZone: tokyoZone, locale: posix
        )
        let open = try XCTUnwrap(planned.first)
        XCTAssertEqual(open.fireDate, try makeDate(
            year: 2026, month: 8, day: 24, hour: 8, minute: 45, timeZoneIdentifier: "Asia/Tokyo"
        ))
        XCTAssertEqual(normalized(open.body), "Opens in 15 minutes, at 9:00 AM")
    }

    func testEventsNotifyAtStartWithApproximateMarkerAndPendingLimit() throws {
        let now = try makeDate(year: 2026, month: 8, day: 24, hour: 8, minute: 0, timeZoneIdentifier: "Asia/Tokyo")
        let boj = EconomicEvent(
            id: "boj-1", kind: .boj, title: nil,
            start: now.addingTimeInterval(4 * 3_600), end: now.addingTimeInterval(5 * 3_600),
            canonicalTimeZoneIdentifier: "Asia/Tokyo"
        )
        let past = EconomicEvent(
            id: "cpi-0", kind: .cpi, title: nil,
            start: now.addingTimeInterval(-3_600), end: now.addingTimeInterval(-1_800),
            canonicalTimeZoneIdentifier: "America/New_York"
        )
        let flood = (1...80).map { index in
            EconomicEvent(
                id: "cpi-\(index)", kind: .cpi, title: nil,
                start: now.addingTimeInterval(Double(index) * 86_400 + 5 * 3_600),
                end: now.addingTimeInterval(Double(index) * 86_400 + 5 * 3_600 + 60),
                canonicalTimeZoneIdentifier: "America/New_York"
            )
        }
        let planned = NotificationPlanner().plan(
            sessions: [], events: [boj, past] + flood, leadMinutes: 5,
            at: now, resolver: SessionResolver(), displayTimeZone: tokyoZone, locale: posix
        )
        XCTAssertEqual(planned.count, NotificationPlanner.pendingLimit)
        XCTAssertFalse(planned.contains { $0.id == "event.cpi-0" })
        let first = try XCTUnwrap(planned.first)
        XCTAssertEqual(first.id, "event.boj-1")
        XCTAssertEqual(first.title, "BOJ Decision")
        XCTAssertEqual(normalized(first.body), "In 5 minutes, at 12:00 PM (approx.)")
        XCTAssertEqual(first.fireDate, boj.start.addingTimeInterval(-300))
    }

    func testNotificationPreferencesDefaultOffAndRoundTrip() throws {
        XCTAssertFalse(MarketPreferences().notifiesAnything)
        XCTAssertEqual(MarketPreferences().notificationLeadMinutes, 0)

        let suite = "MarketSessionsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var preferences = MarketPreferences()
        preferences.notifiedMarkets = [.london]
        preferences.notifiedEventKinds = [.fomc, .cpi]
        preferences.notificationLeadMinutes = 30
        preferences.save(to: defaults)
        XCTAssertEqual(MarketPreferences(defaults: defaults), preferences)

        defaults.set(7, forKey: "notificationLeadMinutes")
        XCTAssertEqual(MarketPreferences(defaults: defaults).notificationLeadMinutes, 0)
    }

    @MainActor
    func testEnablingSchedulesRequestsAuthorizationAndDisablingRemoves() async throws {
        let center = NotificationCenterStub()
        let now = try makeDate(year: 2026, month: 8, day: 24, hour: 8, minute: 0, timeZoneIdentifier: "Asia/Tokyo")
        let event = EconomicEvent(
            id: "cpi-1", kind: .cpi, title: nil,
            start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(3_660),
            canonicalTimeZoneIdentifier: "America/New_York"
        )
        let model = MarketSessionsModel(
            marketExceptions: .empty, economicEvents: [event],
            loginItemService: NotificationLoginItemStub(), notificationCenter: center,
            nowProvider: { now }, displayTimeZoneProvider: { TimeZone(identifier: "Asia/Tokyo")! }
        )
        await model.notificationSync?.value
        XCTAssertEqual(center.removeAllCount, 1, "launch clears stale requests")
        XCTAssertTrue(center.pending.isEmpty)
        XCTAssertEqual(center.authorizationRequests, 0)

        model.setNotifiedEventKind(.cpi, enabled: true)
        await model.notificationSync?.value
        await Task.yield()
        XCTAssertEqual(center.authorizationRequests, 1)
        XCTAssertEqual(model.notificationAuthorization, .authorized)
        XCTAssertEqual(center.pending.keys.sorted(), ["event.cpi-1"])

        model.setNotifiedMarket(.tokyo, enabled: true)
        await model.notificationSync?.value
        XCTAssertEqual(center.authorizationRequests, 1, "authorization is asked once")
        XCTAssertTrue(center.pending.keys.contains("event.cpi-1"))
        XCTAssertTrue(center.pending.keys.contains { $0.hasPrefix("market.tokyo.opens.") })
        XCTAssertLessThanOrEqual(center.pending.count, NotificationPlanner.pendingLimit)

        model.setNotifiedEventKind(.cpi, enabled: false)
        await model.notificationSync?.value
        XCTAssertFalse(center.pending.keys.contains("event.cpi-1"))

        model.setNotifiedMarket(.tokyo, enabled: false)
        await model.notificationSync?.value
        XCTAssertTrue(center.pending.isEmpty)
        XCTAssertEqual(center.removeAllCount, 1)
    }

    @MainActor
    func testUnchangedPlanDoesNotTouchTheCenter() async throws {
        let center = NotificationCenterStub()
        let now = try makeDate(year: 2026, month: 8, day: 24, hour: 8, minute: 0, timeZoneIdentifier: "Asia/Tokyo")
        let model = MarketSessionsModel(
            marketExceptions: .empty, economicEvents: [],
            loginItemService: NotificationLoginItemStub(), notificationCenter: center,
            nowProvider: { now }, displayTimeZoneProvider: { TimeZone(identifier: "Asia/Tokyo")! }
        )
        model.setNotifiedMarket(.london, enabled: true)
        await model.notificationSync?.value
        let adds = center.addCalls
        model.refresh()
        model.refresh()
        await model.notificationSync?.value
        XCTAssertEqual(center.addCalls, adds)
        XCTAssertEqual(center.removeAllCount, 1)
    }

    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func makeDate(
        year: Int, month: Int, day: Int, hour: Int, minute: Int, timeZoneIdentifier: String
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

private extension Calendar {
    static var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }
}

@MainActor
private final class NotificationCenterStub: NotificationCentering {
    var pending: [String: PlannedNotification] = [:]
    var authorizationRequests = 0
    var removeAllCount = 0
    var addCalls = 0
    private var status = NotificationAuthorizationState.notDetermined

    func activate() {}
    func authorizationStatus() async -> NotificationAuthorizationState { status }
    func requestAuthorization() async -> NotificationAuthorizationState {
        authorizationRequests += 1
        status = .authorized
        return status
    }
    func add(_ notifications: [PlannedNotification]) async {
        addCalls += 1
        for notification in notifications { pending[notification.id] = notification }
    }
    func removePending(identifiers: [String]) {
        for identifier in identifiers { pending[identifier] = nil }
    }
    func removeAllPending() {
        removeAllCount += 1
        pending = [:]
    }
}

@MainActor
private final class NotificationLoginItemStub: LoginItemServicing {
    var state: LoginItemState = .disabled
    func setEnabled(_ enabled: Bool) throws { state = enabled ? .enabled : .disabled }
}
