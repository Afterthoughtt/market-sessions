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
            focusPriority: 1
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
            focusPriority: 2
        ),
        MarketSession(
            id: .london,
            code: "LDN",
            name: "London",
            canonicalTimeZoneIdentifier: "Europe/London",
            intervals: [
                // SETS opening auction call.
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(7, 50),
                    end: LocalTime(8),
                    kind: .preMarket
                ),
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(8), end: LocalTime(16, 30)),
            ],
            focusPriority: 3
        ),
        MarketSession(
            id: .tokyo,
            code: "TYO",
            name: "Tokyo",
            canonicalTimeZoneIdentifier: "Asia/Tokyo",
            intervals: [
                // Order acceptance before the morning session; no matching.
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(8),
                    end: LocalTime(9),
                    kind: .preMarket
                ),
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(9), end: LocalTime(11, 30)),
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(11, 30),
                    end: LocalTime(12, 30),
                    kind: .recess
                ),
                SessionInterval(weekdays: Weekday.weekdays, start: LocalTime(12, 30), end: LocalTime(15, 30)),
            ],
            focusPriority: 4
        ),
        MarketSession(
            id: .hongKong,
            code: "HKG",
            name: "Hong Kong",
            canonicalTimeZoneIdentifier: "Asia/Hong_Kong",
            intervals: [
                // Pre-opening auction session.
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(9),
                    end: LocalTime(9, 30),
                    kind: .preMarket
                ),
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
            focusPriority: 5
        ),
        MarketSession(
            id: .shanghai,
            code: "SHG",
            name: "Shanghai",
            canonicalTimeZoneIdentifier: "Asia/Shanghai",
            intervals: [
                // Opening call auction runs 9:15–9:25; the 9:25–9:30 gap before
                // continuous trading stays Pre-Market so the row does not drop
                // to Closed for five minutes.
                SessionInterval(
                    weekdays: Weekday.weekdays,
                    start: LocalTime(9, 15),
                    end: LocalTime(9, 30),
                    kind: .preMarket
                ),
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
            focusPriority: 6
        ),
    ]

    static func session(_ id: MarketSession.ID) -> MarketSession {
        guard let session = sessions.first(where: { $0.id == id }) else {
            preconditionFailure("Missing session definition: \(id)")
        }
        return session
    }
}
