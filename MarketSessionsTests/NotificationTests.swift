import XCTest
import UserNotifications
@testable import MarketSessions

final class NotificationTests: XCTestCase {
    private let posix = Locale(identifier: "en_US_POSIX")
    private let tokyoZone = TimeZone(identifier: "Asia/Tokyo")!

    // Monday 2026-08-24 08:00 JST: Tokyo trades 9:00–11:30 and 12:30–15:30.
    func testMarketsNotifyAtDailyOpenAndFinalCloseOnly() throws {
        let now = try makeDate(year: 2026, month: 8, day: 24, hour: 8, minute: 0, timeZoneIdentifier: "Asia/Tokyo")
        let planned = NotificationPlanner().plan(
            sessions: [MarketScheduleCatalog.session(.tokyo)], events: [], leadMinutes: 0,
            at: now, resolver: SessionResolver(), displayTimeZone: tokyoZone,
            holidayCoverageEnd: nil, locale: posix
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
            at: now, resolver: SessionResolver(), displayTimeZone: tokyoZone,
            holidayCoverageEnd: nil, locale: posix
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
            at: now, resolver: SessionResolver(), displayTimeZone: tokyoZone,
            holidayCoverageEnd: nil, locale: posix
        )
        XCTAssertEqual(planned.count, NotificationPlanner.pendingLimit)
        XCTAssertFalse(planned.contains { $0.id == "event.cpi-0" })
        let first = try XCTUnwrap(planned.first)
        XCTAssertEqual(first.id, "event.boj-1")
        XCTAssertEqual(first.title, "BOJ Decision")
        XCTAssertEqual(normalized(first.body), "In 5 minutes, at ≈ 12:00 PM")
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
        await settle(model)
        XCTAssertEqual(center.removeAllCount, 1, "launch clears stale requests")
        XCTAssertTrue(center.pending.isEmpty)
        XCTAssertEqual(center.authorizationRequests, 0)

        model.setNotifiedEventKind(.cpi, enabled: true)
        await settle(model)
        await Task.yield()
        XCTAssertEqual(center.authorizationRequests, 1)
        XCTAssertEqual(model.notificationAuthorization, .authorized)
        XCTAssertEqual(center.pending.keys.sorted(), ["event.cpi-1"])

        model.setNotifiedMarket(.tokyo, enabled: true)
        await settle(model)
        XCTAssertEqual(center.authorizationRequests, 1, "authorization is asked once")
        XCTAssertTrue(center.pending.keys.contains("event.cpi-1"))
        XCTAssertTrue(center.pending.keys.contains { $0.hasPrefix("market.tokyo.opens.") })
        XCTAssertLessThanOrEqual(center.pending.count, NotificationPlanner.pendingLimit)

        model.setNotifiedEventKind(.cpi, enabled: false)
        await settle(model)
        XCTAssertFalse(center.pending.keys.contains("event.cpi-1"))

        model.setNotifiedMarket(.tokyo, enabled: false)
        await settle(model)
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
        await settle(model)
        let adds = center.addCalls
        model.refresh()
        model.refresh()
        await settle(model)
        XCTAssertEqual(center.addCalls, adds)
        XCTAssertEqual(center.removeAllCount, 1)
    }

    func testCMEMaintenanceIsSilentButWeekendBoundariesRemain() throws {
        let zone = TimeZone(identifier: "America/Chicago")!
        let now = try makeDate(year: 2026, month: 8, day: 23, hour: 12, minute: 0, timeZoneIdentifier: zone.identifier)
        let nextWeek = now.addingTimeInterval(7 * 86_400)
        for lead in [0, 30] {
            let planned = NotificationPlanner().plan(
                sessions: [MarketScheduleCatalog.session(.cmeFutures)], events: [], leadMinutes: lead,
                at: now, resolver: SessionResolver(), displayTimeZone: zone,
                holidayCoverageEnd: nil, locale: posix
            ).filter { $0.fireDate < nextWeek }
            XCTAssertEqual(planned.map(\.fireDate), try [
                makeDate(year: 2026, month: 8, day: 23, hour: 17, minute: 0, timeZoneIdentifier: zone.identifier),
                makeDate(year: 2026, month: 8, day: 28, hour: 16, minute: 0, timeZoneIdentifier: zone.identifier)
            ].map { $0.addingTimeInterval(-Double(lead * 60)) })
        }
    }

    func testCMEEarlyCloseAndHolidayReopeningStillNotify() throws {
        let zone = TimeZone(identifier: "America/Chicago")!
        let index = try MarketExceptionCatalog.loadIndex(bundle: Bundle(for: Self.self))
        for (month, day, closeMinute, reopenDay) in [(11, 26, 0, 26), (12, 24, 15, 27)] {
            let now = try makeDate(year: 2026, month: month, day: day, hour: 10, minute: 0, timeZoneIdentifier: zone.identifier)
            let planned = NotificationPlanner().plan(
                sessions: [MarketScheduleCatalog.session(.cmeFutures)], events: [], leadMinutes: 0,
                at: now, resolver: SessionResolver(exceptions: index), displayTimeZone: zone,
                holidayCoverageEnd: index.coverageEnd, locale: posix
            )
            XCTAssertEqual(Array(planned.prefix(2)).map(\.fireDate), try [
                makeDate(year: 2026, month: month, day: day, hour: 12, minute: closeMinute, timeZoneIdentifier: zone.identifier),
                makeDate(year: 2026, month: month, day: reopenDay, hour: 17, minute: 0, timeZoneIdentifier: zone.identifier)
            ])
        }
    }

    // Holiday data ends 2026-12-31: New York's Dec 31 close still notifies, but
    // nothing is planned for Jan 1, 2027 or later, which may be an unknown holiday.
    func testMarketNotificationsStopWhereHolidayDataEnds() throws {
        let zone = TimeZone(identifier: "America/New_York")!
        let index = try MarketExceptionCatalog.loadIndex(bundle: Bundle(for: Self.self))
        let coverageEnd = try XCTUnwrap(index.coverageEnd)
        let now = try makeDate(year: 2026, month: 12, day: 28, hour: 10, minute: 0, timeZoneIdentifier: zone.identifier)
        let planned = NotificationPlanner().plan(
            sessions: [MarketScheduleCatalog.session(.newYorkCash)], events: [], leadMinutes: 0,
            at: now, resolver: SessionResolver(exceptions: index), displayTimeZone: zone,
            holidayCoverageEnd: coverageEnd, locale: posix
        )
        XCTAssertTrue(planned.contains { $0.fireDate == (try? makeDate(
            year: 2026, month: 12, day: 31, hour: 16, minute: 0, timeZoneIdentifier: zone.identifier
        )) })
        XCTAssertTrue(planned.allSatisfy { $0.fireDate <= coverageEnd })
    }

    func testTriggerUsesGregorianUTCRegardlessOfInterpretingZone() throws {
        // A DST fall-back instant that is ambiguous in New York's local clock.
        let date = try makeDate(year: 2026, month: 11, day: 1, hour: 6, minute: 30, timeZoneIdentifier: "UTC")
        let trigger = NotificationCenterService.trigger(for: date)
        let components = trigger.dateComponents
        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(components.calendar?.identifier, .gregorian)
        XCTAssertEqual(components.calendar?.timeZone.secondsFromGMT(for: date), 0)
        XCTAssertEqual(components.timeZone?.secondsFromGMT(for: date), 0)
        XCTAssertEqual(components.hour, 6)
        for identifier in ["America/New_York", "Asia/Tokyo", "America/Vancouver"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: identifier))
            XCTAssertEqual(calendar.date(from: components), date)
        }
    }

    @MainActor
    func testSchedulingWaitsForAuthorization() async throws {
        let center = NotificationCenterStub()
        center.delayAuthorization = true
        let asked = expectation(description: "authorization requested")
        center.onAuthorizationRequest = { asked.fulfill() }
        let model = try notificationModel(center: center)
        model.setNotifiedMarket(.tokyo, enabled: true)
        await fulfillment(of: [asked], timeout: 2)
        XCTAssertEqual(center.addCalls, 0)
        XCTAssertTrue(center.pending.isEmpty)
        center.finishAuthorization(.authorized)
        await settle(model)
        XCTAssertFalse(center.pending.isEmpty)
        XCTAssertFalse(center.addedWithoutAuthorization)
    }

    @MainActor
    func testDeniedAndUnavailableAuthorizationRetryAfterGrant() async throws {
        for outcome in [NotificationAuthorizationState.denied, .unavailable("registration failed")] {
            let center = NotificationCenterStub()
            center.authorizationOutcome = outcome
            let model = try notificationModel(center: center)
            model.setNotifiedMarket(.tokyo, enabled: true)
            await settle(model)
            XCTAssertEqual(model.notificationAuthorization, outcome)
            XCTAssertEqual(center.addCalls, 0)
            center.status = .authorized
            model.refresh()
            await settle(model)
            XCTAssertFalse(center.pending.isEmpty)
        }
    }

    @MainActor
    func testFirstToggleRequestsAuthorizationEvenWithoutUpcomingEvents() async throws {
        let center = NotificationCenterStub()
        let model = try notificationModel(center: center)
        model.setNotifiedEventKind(.cpi, enabled: true)
        await settle(model)
        XCTAssertEqual(center.authorizationRequests, 1)
        XCTAssertEqual(model.notificationAuthorization, .authorized)
        XCTAssertTrue(center.pending.isEmpty)
    }

    @MainActor
    func testPartialSchedulingFailureRetriesOnlyFailedRequests() async throws {
        let center = NotificationCenterStub()
        center.failNextRequest = true
        let model = try notificationModel(center: center)
        model.setNotifiedMarket(.tokyo, enabled: true)
        await settle(model)
        let failed = try XCTUnwrap(center.attemptedBatches.first?.first)
        let acceptedCount = center.pending.count
        XCTAssertGreaterThan(acceptedCount, 0)
        XCTAssertNil(center.pending[failed])
        model.refresh()
        await settle(model)
        XCTAssertEqual(center.attemptedBatches.last, [failed])
        XCTAssertEqual(center.pending.count, acceptedCount + 1)
        let adds = center.addCalls
        model.refresh()
        await settle(model)
        XCTAssertEqual(center.addCalls, adds)
    }

    @MainActor
    func testDisablingWhileAuthorizationIsPendingLeavesNoAlerts() async throws {
        let center = NotificationCenterStub()
        center.delayAuthorization = true
        let asked = expectation(description: "authorization requested")
        center.onAuthorizationRequest = { asked.fulfill() }
        let model = try notificationModel(center: center)
        model.setNotifiedMarket(.tokyo, enabled: true)
        await fulfillment(of: [asked], timeout: 2)
        model.setNotifiedMarket(.tokyo, enabled: false)
        center.finishAuthorization(.authorized)
        await settle(model)
        XCTAssertTrue(center.pending.isEmpty)
    }

    // macOS keeps reporting notDetermined after a refused registration; the model must
    // not re-prompt every minute, only on Try Again or a selection change.
    @MainActor
    func testFailedRegistrationIsRememberedUntilTryAgain() async throws {
        let center = NotificationCenterStub()
        center.authorizationOutcome = .unavailable("registration failed")
        let model = try notificationModel(center: center)
        model.setNotifiedMarket(.tokyo, enabled: true)
        await settle(model)
        XCTAssertEqual(center.authorizationRequests, 1)
        XCTAssertEqual(center.status, .notDetermined)
        for _ in 0..<3 {
            model.refresh()
            await settle(model)
        }
        XCTAssertEqual(center.authorizationRequests, 1)
        XCTAssertEqual(model.notificationAuthorization, .unavailable("registration failed"))

        center.authorizationOutcome = .authorized
        model.sendTestNotification()
        for _ in 0..<5 { await Task.yield() }
        await settle(model)
        XCTAssertEqual(center.authorizationRequests, 2)
        XCTAssertEqual(model.notificationAuthorization, .authorized)
        XCTAssertFalse(center.pending.isEmpty)
    }

    /// Waits for the current sync, any permission prompt it started, and the replan after it.
    @MainActor
    private func settle(_ model: MarketSessionsModel) async {
        await model.notificationSync?.value
        await model.notificationAuthorizationRequest?.value
        await model.notificationSync?.value
    }

    @MainActor
    private func notificationModel(center: NotificationCenterStub) throws -> MarketSessionsModel {
        let now = try makeDate(year: 2026, month: 8, day: 24, hour: 8, minute: 0, timeZoneIdentifier: "Asia/Tokyo")
        return MarketSessionsModel(
            marketExceptions: .empty, economicEvents: [],
            loginItemService: NotificationLoginItemStub(), notificationCenter: center,
            nowProvider: { now }, displayTimeZoneProvider: { TimeZone(identifier: "Asia/Tokyo")! }
        )
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
    var status = NotificationAuthorizationState.notDetermined
    var authorizationOutcome = NotificationAuthorizationState.authorized
    var delayAuthorization = false
    var onAuthorizationRequest: (() -> Void)?
    private var authorizationContinuation: CheckedContinuation<NotificationAuthorizationState, Never>?
    var failNextRequest = false
    var attemptedBatches: [[String]] = []
    var addedWithoutAuthorization = false

    func activate() {}
    func authorizationStatus() async -> NotificationAuthorizationState { status }
    func requestAuthorization() async -> NotificationAuthorizationState {
        authorizationRequests += 1
        if delayAuthorization {
            return await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                onAuthorizationRequest?()
            }
        }
        // A refused registration leaves the system status at notDetermined.
        if case .unavailable = authorizationOutcome { return authorizationOutcome }
        status = authorizationOutcome
        return status
    }
    func finishAuthorization(_ state: NotificationAuthorizationState) {
        status = state
        authorizationContinuation?.resume(returning: state)
        authorizationContinuation = nil
    }
    func add(_ notifications: [PlannedNotification]) async -> Set<String> {
        addCalls += 1
        attemptedBatches.append(notifications.map(\.id))
        guard status == .authorized else {
            addedWithoutAuthorization = true
            return []
        }
        var accepted: Set<String> = []
        for notification in notifications {
            if failNextRequest {
                failNextRequest = false
                continue
            }
            pending[notification.id] = notification
            accepted.insert(notification.id)
        }
        return accepted
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
