import Foundation

enum MarketScheduleCatalog {
    static let sessions: [MarketSession] = [
        MarketSession(
            id: .cmeMacroFutures,
            name: "CME Globex Macro Futures",
            shortName: "CME Macro Futures",
            iconName: "chart.line.uptrend.xyaxis",
            canonicalTimeZoneIdentifier: "America/Chicago",
            intervals: [
                SessionInterval(
                    weekdays: [.sunday, .monday, .tuesday, .wednesday, .thursday],
                    start: LocalTime(17),
                    end: LocalTime(16),
                    endDayOffset: 1
                ),
                SessionInterval(
                    weekdays: [.monday, .tuesday, .wednesday, .thursday],
                    start: LocalTime(16),
                    end: LocalTime(17),
                    kind: .maintenance("Daily maintenance")
                ),
            ],
            focusPriority: 2,
            caveat: "Settlement timing is approximate. Friday 4:00 PM CT through Sunday 5:00 PM CT is the weekly closure."
        ),
        MarketSession(
            id: .tokyo,
            name: "Tokyo Stock Exchange",
            shortName: "Tokyo",
            iconName: "building.columns",
            canonicalTimeZoneIdentifier: "Asia/Tokyo",
            intervals: [
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(9), end: LocalTime(11, 30)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(11, 30),
                    end: LocalTime(12, 30),
                    kind: .recess("Lunch recess")
                ),
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(12, 30), end: LocalTime(15, 30)),
            ],
            focusPriority: 5,
            caveat: nil
        ),
        MarketSession(
            id: .hongKong,
            name: "Hong Kong Exchange",
            shortName: "Hong Kong",
            iconName: "building.columns",
            canonicalTimeZoneIdentifier: "Asia/Hong_Kong",
            intervals: [
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(9, 30), end: LocalTime(12)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(12),
                    end: LocalTime(13),
                    kind: .recess("Lunch recess")
                ),
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(13), end: LocalTime(16)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(16),
                    end: LocalTime(16, 10),
                    kind: .informational("Closing auction")
                ),
            ],
            focusPriority: 6,
            caveat: "The closing auction ends at a random time between 4:08 and 4:10 PM HKT; 4:10 PM is shown as its outer bound."
        ),
        MarketSession(
            id: .shanghai,
            name: "Shanghai Stock Exchange",
            shortName: "Shanghai",
            iconName: "building.columns",
            canonicalTimeZoneIdentifier: "Asia/Shanghai",
            intervals: [
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(9, 30), end: LocalTime(11, 30)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(11, 30),
                    end: LocalTime(13),
                    kind: .recess("Lunch recess")
                ),
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(13), end: LocalTime(14, 57)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(14, 57),
                    end: LocalTime(15),
                    kind: .trading(phase: "Closing auction")
                ),
            ],
            focusPriority: 7,
            caveat: "The closing auction runs from 2:57 to 3:00 PM China time."
        ),
        MarketSession(
            id: .london,
            name: "London Stock Exchange",
            shortName: "London",
            iconName: "sterlingsign.circle",
            canonicalTimeZoneIdentifier: "Europe/London",
            intervals: [
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(8), end: LocalTime(16, 30)),
            ],
            focusPriority: 3,
            caveat: nil
        ),
        MarketSession(
            id: .newYorkFX,
            name: "New York FX Liquidity",
            shortName: "New York FX",
            iconName: "dollarsign.arrow.circlepath",
            canonicalTimeZoneIdentifier: "America/New_York",
            intervals: [
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(8), end: LocalTime(17)),
            ],
            focusPriority: 4,
            caveat: "Approximately 8:00 AM–5:00 PM ET. This is a liquidity convention, not an exchange session."
        ),
        MarketSession(
            id: .newYorkCash,
            name: "NYSE / Nasdaq Cash",
            shortName: "New York Cash",
            iconName: "dollarsign.circle",
            canonicalTimeZoneIdentifier: "America/New_York",
            intervals: [
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(9, 30), end: LocalTime(16)),
            ],
            focusPriority: 1,
            caveat: nil
        ),
        MarketSession(
            id: .spotFX,
            name: "Weekly Spot FX Liquidity",
            shortName: "Weekly Spot FX",
            iconName: "globe.americas",
            canonicalTimeZoneIdentifier: "America/New_York",
            intervals: [
                SessionInterval(
                    weekdays: [.sunday],
                    start: LocalTime(17),
                    end: LocalTime(17),
                    endDayOffset: 5
                ),
            ],
            focusPriority: nil,
            caveat: "Approximately Sunday 5:00 PM–Friday 5:00 PM ET. Broker access can differ by several minutes."
        ),
        MarketSession(
            id: .cryptoUTC,
            name: "Crypto UTC Day",
            shortName: "Crypto UTC Day",
            iconName: "bitcoinsign.circle",
            canonicalTimeZoneIdentifier: "UTC",
            intervals: [
                SessionInterval(
                    weekdays: Set(Weekday.allCases),
                    start: LocalTime(0),
                    end: LocalTime(0),
                    endDayOffset: 1
                ),
            ],
            focusPriority: nil,
            caveat: "Tracks the standard 12:00 AM UTC daily candle boundary; venue-specific candle anchors can differ."
        ),
    ]

    static func session(_ id: MarketSession.ID) -> MarketSession {
        guard let session = sessions.first(where: { $0.id == id }) else {
            preconditionFailure("Missing session definition: \(id)")
        }
        return session
    }
}
