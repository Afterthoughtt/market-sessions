import Foundation

enum MarketScheduleCatalog {
    static let sessions: [MarketSession] = [
        MarketSession(
            id: .newYorkCash,
            code: "NY",
            name: "New York",
            canonicalTimeZoneIdentifier: "America/New_York",
            intervals: [
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(4),
                    end: LocalTime(9, 30),
                    kind: .preMarket
                ),
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(9, 30), end: LocalTime(16)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(16),
                    end: LocalTime(20),
                    kind: .postMarket
                ),
            ],
            focusPriority: 1,
            approximateTimes: false
        ),
        MarketSession(
            id: .cmeFutures,
            code: "CME",
            name: "CME Futures",
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
                    kind: .maintenance
                ),
            ],
            focusPriority: 2,
            approximateTimes: true
        ),
        MarketSession(
            id: .london,
            code: "LDN",
            name: "London",
            canonicalTimeZoneIdentifier: "Europe/London",
            intervals: [
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(8), end: LocalTime(16, 30)),
            ],
            focusPriority: 3,
            approximateTimes: false
        ),
        MarketSession(
            id: .tokyo,
            code: "TYO",
            name: "Tokyo",
            canonicalTimeZoneIdentifier: "Asia/Tokyo",
            intervals: [
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(9), end: LocalTime(11, 30)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(11, 30),
                    end: LocalTime(12, 30),
                    kind: .recess
                ),
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(12, 30), end: LocalTime(15, 30)),
            ],
            focusPriority: 4,
            approximateTimes: false
        ),
        MarketSession(
            id: .hongKong,
            code: "HKG",
            name: "Hong Kong",
            canonicalTimeZoneIdentifier: "Asia/Hong_Kong",
            intervals: [
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(9, 30), end: LocalTime(12)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(12),
                    end: LocalTime(13),
                    kind: .recess
                ),
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(13), end: LocalTime(16)),
                // Ends at a random moment between 4:08 and 4:10 PM HKT; 4:10 is the outer bound.
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(16),
                    end: LocalTime(16, 10),
                    kind: .auction
                ),
            ],
            focusPriority: 5,
            approximateTimes: false
        ),
        MarketSession(
            id: .shanghai,
            code: "SHG",
            name: "Shanghai",
            canonicalTimeZoneIdentifier: "Asia/Shanghai",
            intervals: [
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(9, 30), end: LocalTime(11, 30)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(11, 30),
                    end: LocalTime(13),
                    kind: .recess
                ),
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(13), end: LocalTime(14, 57)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(14, 57),
                    end: LocalTime(15),
                    kind: .auction
                ),
            ],
            focusPriority: 6,
            approximateTimes: false
        ),
    ]

    static func session(_ id: MarketSession.ID) -> MarketSession {
        guard let session = sessions.first(where: { $0.id == id }) else {
            preconditionFailure("Missing session definition: \(id)")
        }
        return session
    }
}
