import Foundation

/// A single deviation from a market's recurring hours: a full holiday closure or
/// an early close. Dates and times are in the market's canonical time zone.
struct MarketException: Hashable, Sendable {
    enum Kind: String, Decodable, Hashable, Sendable {
        case holiday
        case earlyClose
    }

    let market: MarketSession.ID
    let year: Int
    let month: Int
    let day: Int
    let kind: Kind
    /// Trading stops at this local time — required for `earlyClose`.
    let close: LocalTime?
    let note: String?

    var dateKey: String {
        MarketExceptionIndex.key(year: year, month: month, day: day)
    }
}

/// Fast lookup of exceptions by market and canonical-zone calendar date.
struct MarketExceptionIndex: Sendable {
    private let byMarketDate: [MarketSession.ID: [String: MarketException]]
    /// Last date the bundled exception data covers — for staleness display.
    let coverageEnd: Date?

    static let empty = MarketExceptionIndex(exceptions: [], coverageEnd: nil)

    init(exceptions: [MarketException], coverageEnd: Date?) {
        var index: [MarketSession.ID: [String: MarketException]] = [:]
        for exception in exceptions {
            index[exception.market, default: [:]][exception.dateKey] = exception
        }
        self.byMarketDate = index
        self.coverageEnd = coverageEnd
    }

    func exception(for market: MarketSession.ID, on date: Date, calendar: Calendar) -> MarketException? {
        byMarketDate[market]?[Self.key(for: date, calendar: calendar)]
    }

    static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return key(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    static func key(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
