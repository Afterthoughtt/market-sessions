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
            "Fed Chair speech"
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
        case .fedSpeech: "Fed Chair Speech"
        case .fomcMinutes: "FOMC Minutes"
        case .gdp: "U.S. GDP (Advance)"
        case .ecb: "ECB Decision"
        case .boj: "BOJ Decision"
        case .ppi: "U.S. PPI"
        }
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
