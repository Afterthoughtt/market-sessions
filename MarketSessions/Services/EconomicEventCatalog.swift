import Foundation

enum EconomicEventCatalogError: Error, Equatable {
    case missingResources
    case invalidDate(String)
    case invalidTime(String)
    case invalidTimeZone(String)
    case invalidDuration(Int)
    case duplicateID(String)
}

enum EconomicEventCatalog {
    private struct FileContents: Decodable {
        let events: [BundledEvent]
    }

    private struct BundledEvent: Decodable {
        let id: String
        let kind: EconomicEventKind
        let title: String?
        let date: String
        let time: String
        let durationMinutes: Int
        let timeZone: String
    }

    static func loadAll(bundle: Bundle = .main) throws -> [EconomicEvent] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let eventURLs = urls
            .filter { $0.lastPathComponent.hasPrefix("events-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !eventURLs.isEmpty else {
            throw EconomicEventCatalogError.missingResources
        }

        return try eventURLs
            .flatMap { try decode(Data(contentsOf: $0)) }
            .validatedForUniqueIDs()
            .sorted(by: eventOrder)
    }

    static func decode(_ data: Data) throws -> [EconomicEvent] {
        let contents = try JSONDecoder().decode(FileContents.self, from: data)
        return try contents.events.map(resolve)
    }

    private static func resolve(_ bundled: BundledEvent) throws -> EconomicEvent {
        let dateParts = try integers(in: bundled.date, separatedBy: "-", count: 3)
        let timeParts = try integers(in: bundled.time, separatedBy: ":", count: 2)
        guard bundled.durationMinutes > 0 else {
            throw EconomicEventCatalogError.invalidDuration(bundled.durationMinutes)
        }
        guard let timeZone = TimeZone(identifier: bundled.timeZone) else {
            throw EconomicEventCatalogError.invalidTimeZone(bundled.timeZone)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let start = calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: dateParts[0],
            month: dateParts[1],
            day: dateParts[2],
            hour: timeParts[0],
            minute: timeParts[1]
        )),
        calendar.component(.year, from: start) == dateParts[0],
        calendar.component(.month, from: start) == dateParts[1],
        calendar.component(.day, from: start) == dateParts[2],
        calendar.component(.hour, from: start) == timeParts[0],
        calendar.component(.minute, from: start) == timeParts[1] else {
            throw EconomicEventCatalogError.invalidDate(bundled.date)
        }

        return EconomicEvent(
            id: bundled.id,
            kind: bundled.kind,
            title: bundled.title,
            start: start,
            end: start.addingTimeInterval(TimeInterval(bundled.durationMinutes * 60)),
            canonicalTimeZoneIdentifier: bundled.timeZone
        )
    }

    private static func integers(
        in value: String,
        separatedBy separator: Character,
        count: Int
    ) throws -> [Int] {
        let parts = value.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == count,
              parts.allSatisfy({ Int($0) != nil }) else {
            if separator == ":" {
                throw EconomicEventCatalogError.invalidTime(value)
            }
            throw EconomicEventCatalogError.invalidDate(value)
        }
        return parts.map { Int($0)! }
    }

    private static func eventOrder(_ lhs: EconomicEvent, _ rhs: EconomicEvent) -> Bool {
        if lhs.start != rhs.start {
            return lhs.start < rhs.start
        }
        if lhs.kind.rank != rhs.kind.rank {
            return lhs.kind.rank < rhs.kind.rank
        }
        return lhs.id < rhs.id
    }
}

/// Rolling window: everything within the horizon, and never fewer than
/// `minimumCount` events (reaching further ahead when the near term is quiet),
/// so the section always has content while events remain in the catalog.
struct UpcomingEconomicEventResolver: Sendable {
    func resolve(
        _ events: [EconomicEvent],
        at now: Date,
        horizon: TimeInterval = 14 * 86_400,
        minimumCount: Int = 5,
        enabledKinds: Set<EconomicEventKind> = Set(EconomicEventKind.allCases.filter(\.isDefault))
    ) -> UpcomingEconomicEvents {
        let selected = events.filter { enabledKinds.contains($0.kind) }
        let upcoming = selected
            .filter { $0.end > now }
            .sorted { lhs, rhs in
                if lhs.start != rhs.start {
                    return lhs.start < rhs.start
                }
                if lhs.kind.rank != rhs.kind.rank {
                    return lhs.kind.rank < rhs.kind.rank
                }
                return lhs.id < rhs.id
            }

        let cutoff = now.addingTimeInterval(horizon)
        var within = upcoming.filter { $0.start <= cutoff }
        if within.count < minimumCount {
            within = Array(upcoming.prefix(minimumCount))
        }
        return UpcomingEconomicEvents(
            events: within,
            scheduleEnd: events.map(\.end).max()
        )
    }
}

private extension Array where Element == EconomicEvent {
    func validatedForUniqueIDs() throws -> [EconomicEvent] {
        var ids: Set<EconomicEvent.ID> = []
        for event in self where !ids.insert(event.id).inserted {
            throw EconomicEventCatalogError.duplicateID(event.id)
        }
        return self
    }
}
