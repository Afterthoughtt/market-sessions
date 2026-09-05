import Foundation

enum EconomicEventKind: String, CaseIterable, Codable, Hashable, Sendable {
    case fomc
    case cpi
    case employment
    case pce
    case retailSales
    case fedSpeech
    case fomcMinutes
    case gdp
    case ecb
    case boj
    case ppi

    var title: String {
        switch self {
        case .fomc:
            "FOMC decision + press conference"
        case .cpi:
            "U.S. CPI"
        case .employment:
            "Employment situation / NFP"
        case .pce:
            "U.S. PCE"
        case .retailSales:
            "U.S. retail sales"
        case .fedSpeech:
            "Fed Chair testimony and Jackson Hole keynote"
        case .fomcMinutes:
            "FOMC minutes"
        case .gdp:
            "U.S. GDP (advance)"
        case .ecb:
            "ECB rate decision"
        case .boj:
            "BOJ rate decision"
        case .ppi:
            "U.S. PPI"
        }
    }

    /// Short labels for compact rows; title retains the complete description.
    var compactTitle: String {
        switch self {
        case .fomc: "FOMC Decision"
        case .cpi: "U.S. CPI"
        case .employment: "U.S. Jobs Report"
        case .pce: "U.S. PCE"
        case .retailSales: "U.S. Retail Sales"
        case .fedSpeech: "Fed Chair Appearances"
        case .fomcMinutes: "FOMC Minutes"
        case .gdp: "U.S. GDP (Advance)"
        case .ecb: "ECB Decision"
        case .boj: "BOJ Decision"
        case .ppi: "U.S. PPI"
        }
    }

    enum Category: CaseIterable, Sendable {
        case usRelease
        case centralBank
    }

    var category: Category {
        switch self {
        case .cpi, .employment, .pce, .retailSales, .gdp, .ppi: .usRelease
        case .fomc, .fedSpeech, .fomcMinutes, .ecb, .boj: .centralBank
        }
    }

    /// One-line explanation for Settings tooltips: what the release measures and who publishes it.
    var detail: String {
        switch self {
        case .employment: "Nonfarm payrolls and unemployment · BLS"
        case .cpi: "Consumer Price Index · BLS"
        case .pce: "Personal Consumption Expenditures inflation · BEA"
        case .ppi: "Producer Price Index · BLS"
        case .retailSales: "Advance monthly sales · Census Bureau"
        case .gdp: "First quarterly estimate · BEA"
        case .fomc: "Rate decision and press conference as one window"
        case .fomcMinutes: "Released three weeks after each meeting"
        case .fedSpeech: "Jackson Hole keynote and semiannual congressional testimony; other Chair speeches are announced only weeks ahead"
        case .ecb: "Rate decision and press conference"
        case .boj: "Rate decision; announcement time is approximate"
        }
    }

    /// BOJ decisions have no fixed announcement time; the stored 12:00 JST is an approximation.
    var hasApproximateTime: Bool { self == .boj }

    /// Kinds in a category, in display rank order.
    static func kinds(in category: Category) -> [EconomicEventKind] {
        allCases.filter { $0.category == category }.sorted { $0.rank < $1.rank }
    }

    /// The initial high-impact selection, before the user customizes Settings.
    var isDefault: Bool {
        switch self {
        case .fomc, .cpi, .employment, .fedSpeech, .pce: true
        case .retailSales, .fomcMinutes, .gdp, .ecb, .boj, .ppi: false
        }
    }

    var rank: Int {
        switch self {
        case .fomc: 1
        case .cpi: 2
        case .employment: 3
        case .pce: 4
        case .retailSales: 5
        case .fedSpeech: 6
        case .fomcMinutes: 7
        case .gdp: 8
        case .ecb: 9
        case .boj: 10
        case .ppi: 11
        }
    }
}

struct EconomicEvent: Identifiable, Hashable, Sendable {
    enum Phase: Hashable, Sendable {
        case upcoming
        case live
        case past
    }

    let id: String
    let kind: EconomicEventKind
    /// Optional per-event title override — e.g. "Jackson Hole keynote" for a fedSpeech.
    let title: String?
    let start: Date
    let end: Date
    let canonicalTimeZoneIdentifier: String

    var displayTitle: String {
        title ?? kind.title
    }

    var compactTitle: String {
        // Preserve specific speech names instead of reducing them to a generic category.
        title ?? kind.compactTitle
    }

    var canonicalTimeZone: TimeZone {
        guard let timeZone = TimeZone(identifier: canonicalTimeZoneIdentifier) else {
            preconditionFailure("Unknown event time zone: \(canonicalTimeZoneIdentifier)")
        }
        return timeZone
    }

    func phase(at date: Date) -> Phase {
        if date < start {
            .upcoming
        } else if date < end {
            .live
        } else {
            .past
        }
    }

    func remainingMinutes(at date: Date) -> Int? {
        let target: Date
        switch phase(at: date) {
        case .upcoming:
            target = start
        case .live:
            target = end
        case .past:
            return nil
        }

        return max(0, Int(ceil(target.timeIntervalSince(date) / 60)))
    }
}

struct UpcomingEconomicEvents: Hashable, Sendable {
    let events: [EconomicEvent]
    /// End of the last event in the bundled catalog — surfaced when the schedule
    /// is nearly exhausted so staleness is visible instead of the section going quiet.
    let scheduleEnd: Date?

    static let empty = UpcomingEconomicEvents(events: [], scheduleEnd: nil)
}
