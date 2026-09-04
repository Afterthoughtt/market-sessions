import XCTest
@testable import MarketSessions

final class SettingsTests: XCTestCase {
    func testDefaultsShowAllMarketsDefaultEventsAndSystemTime() {
        let preferences = MarketPreferences()
        XCTAssertEqual(preferences.visibleMarkets, Set(MarketSession.ID.allCases))
        XCTAssertEqual(preferences.eventKinds, Set(EconomicEventKind.allCases.filter(\.isDefault)))
        XCTAssertNil(preferences.timeZoneIdentifier)
        let system = TimeZone(identifier: "America/Vancouver")!
        XCTAssertEqual(preferences.displayTimeZone(system: system), system)
    }

    func testPreferencesRoundTripIncludingEmptySelections() throws {
        let suite = "MarketSessionsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var preferences = MarketPreferences()
        preferences.visibleMarkets = [.tokyo, .london]
        preferences.eventKinds = [.boj, .ecb]
        preferences.timeZoneIdentifier = "Asia/Tokyo"
        preferences.save(to: defaults)
        XCTAssertEqual(MarketPreferences(defaults: defaults), preferences)

        preferences.visibleMarkets = []
        preferences.eventKinds = []
        preferences.timeZoneIdentifier = nil
        preferences.save(to: defaults)
        XCTAssertEqual(MarketPreferences(defaults: defaults), preferences)
    }

    func testInvalidStoredTimeZoneFallsBackToSystem() throws {
        let suite = "MarketSessionsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("Not/AZone", forKey: "displayTimeZone")
        let preferences = MarketPreferences(defaults: defaults)
        XCTAssertNil(preferences.timeZoneIdentifier)
        XCTAssertEqual(preferences.displayTimeZone(system: .gmt), .gmt)
    }

    @MainActor
    func testMarketSelectionUpdatesPopoverAndStatusItemImmediately() {
        let model = makeModel()
        for market in model.availableMarkets where market.id != .tokyo {
            model.setMarket(market.id, visible: false)
        }
        XCTAssertEqual(model.orderedSessions.map(\.id), [.tokyo])
        XCTAssertEqual(model.nextTransitionSession?.id, .tokyo)

        model.setMarket(.tokyo, visible: false)
        XCTAssertTrue(model.orderedSessions.isEmpty)
        XCTAssertNil(model.nextTransitionSession)
        XCTAssertNil(model.focus.hero)
        XCTAssertNil(model.focus.nextToOpen)

        model.setMarket(.london, visible: true)
        XCTAssertEqual(model.orderedSessions.map(\.id), [.london])
        XCTAssertEqual(model.nextTransitionSession?.id, .london)
    }

    @MainActor
    func testSelectedEventsIncludePreviouslyHiddenKindsAndCanBeEmpty() {
        let model = makeModel()
        for kind in EconomicEventKind.allCases {
            model.setEventKind(kind, visible: false)
        }
        XCTAssertTrue(model.upcomingEvents.events.isEmpty)
        model.setEventKind(.ecb, visible: true)
        XCTAssertEqual(model.upcomingEvents.events.map(\.kind), [.ecb])
        model.setEventKind(.cpi, visible: true)
        XCTAssertEqual(Set(model.upcomingEvents.events.map(\.kind)), [.ecb, .cpi])
    }

    @MainActor
    func testTimeZoneOverrideDoesNotChangeMarketInstantsOrUTCClose() {
        let model = makeModel()
        let original = model.orderedSessions
        let utcMinutes = model.utcDayRemainingMinutes
        model.setDisplayTimeZone("Asia/Tokyo")
        XCTAssertEqual(model.displayTimeZone.identifier, "Asia/Tokyo")
        XCTAssertEqual(model.orderedSessions, original)
        XCTAssertEqual(model.utcDayRemainingMinutes, utcMinutes)

        model.setDisplayTimeZone("Not/AZone")
        XCTAssertEqual(model.displayTimeZone.identifier, "Asia/Tokyo")
        model.setDisplayTimeZone(nil)
        XCTAssertEqual(model.displayTimeZone.identifier, "America/Vancouver")
    }

    @MainActor
    func testModelReloadsSavedPreferences() throws {
        let suite = "MarketSessionsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = makeModel(defaults: defaults)
        first.setMarket(.tokyo, visible: false)
        first.setEventKind(.ecb, visible: true)
        first.setDisplayTimeZone("Europe/London")
        let reloaded = makeModel(defaults: defaults)
        XCTAssertEqual(reloaded.preferences, first.preferences)
        XCTAssertFalse(reloaded.orderedSessions.contains { $0.id == .tokyo })
        XCTAssertEqual(reloaded.displayTimeZone.identifier, "Europe/London")
    }

    func testCustomZoneFollowsDSTInsteadOfPersistingAnOffset() throws {
        var preferences = MarketPreferences()
        preferences.timeZoneIdentifier = "America/New_York"
        let zone = preferences.displayTimeZone(system: .gmt)
        let formatter = ISO8601DateFormatter()
        let summer = try XCTUnwrap(formatter.date(from: "2026-07-01T12:00:00Z"))
        let winter = try XCTUnwrap(formatter.date(from: "2026-12-01T12:00:00Z"))
        XCTAssertEqual(zone.secondsFromGMT(for: summer), -4 * 3_600)
        XCTAssertEqual(zone.secondsFromGMT(for: winter), -5 * 3_600)
    }

    @MainActor
    func testAutomaticZoneTracksSystemChangesWhileAnOverrideStaysFixed() {
        let system = MutableSystemZone()
        let model = MarketSessionsModel(
            marketExceptions: .empty, economicEvents: [],
            loginItemService: SettingsLoginItemStub(),
            nowProvider: { Date(timeIntervalSince1970: 1_800_000_000) },
            displayTimeZoneProvider: { system.zone }
        )
        system.zone = TimeZone(identifier: "Asia/Tokyo")!
        model.refresh()
        XCTAssertEqual(model.displayTimeZone.identifier, "Asia/Tokyo")

        model.setDisplayTimeZone("Europe/London")
        system.zone = TimeZone(identifier: "America/New_York")!
        model.refresh()
        XCTAssertEqual(model.displayTimeZone.identifier, "Europe/London")
        model.setDisplayTimeZone(nil)
        XCTAssertEqual(model.displayTimeZone.identifier, "America/New_York")
    }

    @MainActor
    private func makeModel(defaults: UserDefaults? = nil) -> MarketSessionsModel {
        let now = ISO8601DateFormatter().date(from: "2026-09-04T01:31:00Z")!
        let events = [EconomicEventKind.cpi, .ecb].enumerated().map { index, kind in
            EconomicEvent(
                id: kind.rawValue, kind: kind, title: nil,
                start: now.addingTimeInterval(Double(index + 1) * 3_600),
                end: now.addingTimeInterval(Double(index + 1) * 3_600 + 60),
                canonicalTimeZoneIdentifier: "UTC"
            )
        }
        return MarketSessionsModel(
            marketExceptions: .empty,
            economicEvents: events,
            loginItemService: SettingsLoginItemStub(),
            nowProvider: { now },
            displayTimeZoneProvider: { TimeZone(identifier: "America/Vancouver")! },
            preferencesStore: defaults
        )
    }
}

@MainActor
private final class SettingsLoginItemStub: LoginItemServicing {
    var state: LoginItemState = .disabled
    func setEnabled(_ enabled: Bool) throws { state = enabled ? .enabled : .disabled }
}

private final class MutableSystemZone: @unchecked Sendable {
    var zone = TimeZone(identifier: "America/Vancouver")!
}
