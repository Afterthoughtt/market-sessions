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
