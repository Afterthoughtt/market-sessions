import Foundation

enum MarketExceptionCatalogError: Error, Equatable {
    case missingResources
    case unknownMarket(String)
    case invalidDate(String)
    case invalidTime(String)
    case missingCloseTime(String)
}

/// Loads bundled `market-exceptions-<year>.json` files: holiday closures and
/// early closes per market, keyed by session code, dated in canonical zones.
enum MarketExceptionCatalog {
    private struct FileContents: Decodable {
        let coverageEnd: String?
        let exceptions: [BundledException]
    }

    private struct BundledException: Decodable {
        let market: String
        let date: String
        let type: MarketException.Kind
        let close: String?
        let name: String?
        let note: String?
    }

    static func loadIndex(bundle: Bundle = .main) throws -> MarketExceptionIndex {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let exceptionURLs = urls
            .filter { $0.lastPathComponent.hasPrefix("market-exceptions-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !exceptionURLs.isEmpty else {
            throw MarketExceptionCatalogError.missingResources
        }

        var exceptions: [MarketException] = []
        var coverageEnd: Date?
        for url in exceptionURLs {
            let contents = try JSONDecoder().decode(FileContents.self, from: Data(contentsOf: url))
            exceptions += try contents.exceptions.map(resolve)
            if let end = contents.coverageEnd {
                let parts = try dateParts(end)
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
                if let date = calendar.date(from: DateComponents(
                    year: parts[0], month: parts[1], day: parts[2], hour: 23, minute: 59
                )) {
                    coverageEnd = max(coverageEnd ?? .distantPast, date)
                }
            }
        }
        return MarketExceptionIndex(exceptions: exceptions, coverageEnd: coverageEnd)
    }

    private static func resolve(_ bundled: BundledException) throws -> MarketException {
        guard let session = MarketScheduleCatalog.sessions.first(where: { $0.code == bundled.market }) else {
            throw MarketExceptionCatalogError.unknownMarket(bundled.market)
        }
        let parts = try dateParts(bundled.date)

        var close: LocalTime?
        if bundled.type == .earlyClose {
            guard let closeString = bundled.close else {
                throw MarketExceptionCatalogError.missingCloseTime(bundled.date)
            }
            let timeParts = closeString.split(separator: ":", omittingEmptySubsequences: false)
            guard timeParts.count == 2,
                  let hour = Int(timeParts[0]), let minute = Int(timeParts[1]),
                  (0..<24).contains(hour), (0..<60).contains(minute) else {
                throw MarketExceptionCatalogError.invalidTime(closeString)
            }
            close = LocalTime(hour, minute)
        }

        return MarketException(
            market: session.id,
            year: parts[0],
            month: parts[1],
            day: parts[2],
            kind: bundled.type,
            close: close,
            name: bundled.name,
            note: bundled.note
        )
    }

    private static func dateParts(_ value: String) throws -> [Int] {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ Int($0) != nil }) else {
            throw MarketExceptionCatalogError.invalidDate(value)
        }
        return parts.map { Int($0)! }
    }
}

/// A holiday or early close coming up for a shown market, for the popover's Closures rows.
struct MarketClosure: Identifiable, Hashable, Sendable {
    let session: MarketSession
    let exception: MarketException
    /// Holiday: the start of its canonical-zone day. Early close: the close instant.
    let date: Date
    /// The zone its day is shown and sorted in: the market's own for a holiday, the
    /// display zone for an early close.
    let dayTimeZone: TimeZone

    var id: String { "\(session.id.rawValue)-\(exception.dateKey)" }
}

struct UpcomingClosures: Hashable, Sendable {
    let closures: [MarketClosure]
    /// The look-ahead window runs past the bundled holiday data, so later closures may be missing.
    let passesCoverage: Bool

    static let empty = UpcomingClosures(closures: [], passesCoverage: false)
}

/// Holidays and early closes in each market's next `days` canonical-zone days. Today's
/// holiday is left out (it is the Holiday section); today's early close stays until it
/// passes, since the row shows it only once the market is open (the model drops it then).
/// Rows sort by the day they show: a holiday's own date, an early close's date in the
/// display zone.
struct UpcomingClosureResolver: Sendable {
    func resolve(
        _ index: MarketExceptionIndex,
        sessions: [MarketSession],
        at now: Date,
        displayTimeZone: TimeZone,
        days: Int = 7
    ) -> UpcomingClosures {
        guard !sessions.isEmpty else { return .empty }
        var closures: [(day: String, closure: MarketClosure)] = []
        var display = Calendar(identifier: .gregorian)
        display.timeZone = displayTimeZone
        for session in sessions {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = session.canonicalTimeZone
            let today = calendar.startOfDay(for: now)
            guard let last = calendar.date(byAdding: .day, value: days, to: today) else { continue }
            for exception in index.all where exception.market == session.id {
                guard let day = calendar.date(from: DateComponents(
                    year: exception.year, month: exception.month, day: exception.day
                )), day >= today, day <= last else { continue }
                var date = day
                var shownDay = exception.dateKey
                if exception.kind == .earlyClose, let close = exception.close,
                   let closeDate = calendar.date(bySettingHour: close.hour, minute: close.minute, second: 0, of: day) {
                    guard closeDate > now else { continue }
                    date = closeDate
                    shownDay = MarketExceptionIndex.key(for: closeDate, calendar: display)
                } else if day == today {
                    continue
                }
                let dayTimeZone = exception.kind == .earlyClose ? displayTimeZone : session.canonicalTimeZone
                closures.append((shownDay, MarketClosure(
                    session: session, exception: exception, date: date, dayTimeZone: dayTimeZone
                )))
            }
        }
        closures.sort { lhs, rhs in
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            // Same day: holidays first, then early closes by time; ties by market priority.
            let lhsHoliday = lhs.closure.exception.kind == .holiday
            let rhsHoliday = rhs.closure.exception.kind == .holiday
            if lhsHoliday != rhsHoliday { return lhsHoliday }
            if !lhsHoliday, lhs.closure.date != rhs.closure.date { return lhs.closure.date < rhs.closure.date }
            return lhs.closure.session.focusPriority < rhs.closure.session.focusPriority
        }
        let horizon = now.addingTimeInterval(TimeInterval(days + 1) * 86_400)
        return UpcomingClosures(
            closures: closures.map(\.closure),
            passesCoverage: index.coverageEnd.map { $0 < horizon } ?? false
        )
    }
}
