import Foundation

/// Persist identifiers, not UTC offsets: a selected zone continues to follow DST.
struct MarketPreferences: Equatable {
    var visibleMarkets = Set(MarketSession.ID.allCases)
    var eventKinds = Set(EconomicEventKind.allCases.filter(\.isDefault))
    var timeZoneIdentifier: String?
    /// Notification selections are independent of what the popover shows; both default to nothing.
    var notifiedMarkets: Set<MarketSession.ID> = []
    var notifiedEventKinds: Set<EconomicEventKind> = []
    var notificationLeadMinutes = 0

    var notifiesAnything: Bool { !notifiedMarkets.isEmpty || !notifiedEventKinds.isEmpty }

    private enum Key {
        static let markets = "visibleMarkets"
        static let events = "visibleEventKinds"
        static let timeZone = "displayTimeZone"
        static let notifiedMarkets = "notifiedMarkets"
        static let notifiedEvents = "notifiedEventKinds"
        static let notificationLead = "notificationLeadMinutes"
    }

    init() {}

    init(defaults: UserDefaults) {
        if let stored = defaults.stringArray(forKey: Key.markets) {
            visibleMarkets = Set(stored.compactMap(MarketSession.ID.init(rawValue:)))
        }
        if let stored = defaults.stringArray(forKey: Key.events) {
            eventKinds = Set(stored.compactMap(EconomicEventKind.init(rawValue:)))
        }
        if let identifier = defaults.string(forKey: Key.timeZone),
           TimeZone(identifier: identifier) != nil {
            timeZoneIdentifier = identifier
        }
        if let stored = defaults.stringArray(forKey: Key.notifiedMarkets) {
            notifiedMarkets = Set(stored.compactMap(MarketSession.ID.init(rawValue:)))
        }
        if let stored = defaults.stringArray(forKey: Key.notifiedEvents) {
            notifiedEventKinds = Set(stored.compactMap(EconomicEventKind.init(rawValue:)))
        }
        let lead = defaults.integer(forKey: Key.notificationLead)
        if NotificationPlanner.leadOptions.contains(lead) {
            notificationLeadMinutes = lead
        }
    }

    func save(to defaults: UserDefaults) {
        defaults.set(visibleMarkets.map(\.rawValue).sorted(), forKey: Key.markets)
        defaults.set(eventKinds.map(\.rawValue).sorted(), forKey: Key.events)
        if let timeZoneIdentifier {
            defaults.set(timeZoneIdentifier, forKey: Key.timeZone)
        } else {
            defaults.removeObject(forKey: Key.timeZone)
        }
        defaults.set(notifiedMarkets.map(\.rawValue).sorted(), forKey: Key.notifiedMarkets)
        defaults.set(notifiedEventKinds.map(\.rawValue).sorted(), forKey: Key.notifiedEvents)
        defaults.set(notificationLeadMinutes, forKey: Key.notificationLead)
    }

    func displayTimeZone(system: TimeZone) -> TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? system
    }
}
