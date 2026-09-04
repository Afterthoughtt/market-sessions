import Foundation

struct MarketSession: Identifiable, Hashable, Sendable {
    enum ID: String, CaseIterable, Hashable, Sendable {
        case newYorkCash
        case cmeFutures
        case london
        case tokyo
        case hongKong
        case shanghai
    }

    let id: ID
    /// Ticker-style code shown in rows, rings, and the menu bar (`NY`, `CME`, …).
    let code: String
    let name: String
    let canonicalTimeZoneIdentifier: String
    let intervals: [SessionInterval]
    /// Lower wins when choosing the emphasized open session.
    let focusPriority: Int

    var canonicalTimeZone: TimeZone {
        guard let timeZone = TimeZone(identifier: canonicalTimeZoneIdentifier) else {
            preconditionFailure("Unknown canonical time zone: \(canonicalTimeZoneIdentifier)")
        }
        return timeZone
    }
}
