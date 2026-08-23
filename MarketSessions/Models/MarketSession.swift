import Foundation

struct MarketSession: Identifiable, Hashable, Sendable {
    enum ID: String, CaseIterable, Hashable, Sendable {
        case cmeMacroFutures
        case tokyo
        case hongKong
        case shanghai
        case london
        case newYorkFX
        case newYorkCash
        case spotFX
        case cryptoUTC
    }

    let id: ID
    let name: String
    let shortName: String
    let iconName: String
    let canonicalTimeZoneIdentifier: String
    let intervals: [SessionInterval]
    let focusPriority: Int?
    let caveat: String?

    var canonicalTimeZone: TimeZone {
        guard let timeZone = TimeZone(identifier: canonicalTimeZoneIdentifier) else {
            preconditionFailure("Unknown canonical time zone: \(canonicalTimeZoneIdentifier)")
        }
        return timeZone
    }
}
