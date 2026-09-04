import Foundation

/// Persist identifiers, not UTC offsets: a selected zone continues to follow DST.
struct MarketPreferences: Equatable {
    var visibleMarkets = Set(MarketSession.ID.allCases)
    var eventKinds = Set(EconomicEventKind.allCases.filter(\.isDefault))
    var timeZoneIdentifier: String?

    private enum Key {
        static let markets = "visibleMarkets"
        static let events = "visibleEventKinds"
        static let timeZone = "displayTimeZone"
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
    }

    func save(to defaults: UserDefaults) {
        defaults.set(visibleMarkets.map(\.rawValue).sorted(), forKey: Key.markets)
        defaults.set(eventKinds.map(\.rawValue).sorted(), forKey: Key.events)
        if let timeZoneIdentifier {
            defaults.set(timeZoneIdentifier, forKey: Key.timeZone)
        } else {
            defaults.removeObject(forKey: Key.timeZone)
        }
    }

    func displayTimeZone(system: TimeZone) -> TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? system
    }
}
