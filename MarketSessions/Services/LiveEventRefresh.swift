import Foundation

/// Official schedule pages read once a week to update bundled event dates. Only
/// publishers that serve plain pages and allow it: BLS blocks apps, and every
/// exchange's holidays stay bundled (CME blocks apps; NYSE, LSE and HKEX terms
/// forbid automated access). A source that fails keeps its bundled dates.
enum LiveEventSource: String, CaseIterable, Codable, Sendable {
    case fedMeetings
    case fedMinutes
    case beaPersonalIncome
    case beaGDP
    case censusRetail
    case ecb
    case boj

    var kind: EconomicEventKind {
        switch self {
        case .fedMeetings: .fomc
        case .fedMinutes: .fomcMinutes
        case .beaPersonalIncome: .pce
        case .beaGDP: .gdp
        case .censusRetail: .retailSales
        case .ecb: .ecb
        case .boj: .boj
        }
    }

    /// Named in Settings when the source fails.
    var host: String {
        switch self {
        case .fedMeetings, .fedMinutes: "federalreserve.gov"
        case .beaPersonalIncome, .beaGDP: "bea.gov"
        case .censusRetail: "census.gov"
        case .ecb: "ecb.europa.eu"
        case .boj: "boj.or.jp"
        }
    }

    /// Fewer parsed dates than this means the page changed, not the schedule. Monthly
    /// pages have no minimum: a month without minutes lists none.
    var minimumCount: Int {
        switch self {
        case .fedMeetings: 8
        case .fedMinutes: 0
        case .beaPersonalIncome, .censusRetail: 6
        case .ecb, .boj, .beaGDP: 4
        }
    }

    /// One page per month (Fed minutes): a month not yet published is a 404, and a
    /// page covers its whole month rather than the dates it lists.
    var readsMonthlyPages: Bool { self == .fedMinutes }

    /// Pages that may not be posted yet: a Fed minutes month, or BEA's next-year
    /// schedule, which fills in during the year. A 404, or a next-year page listing
    /// fewer than every advance estimate, covers nothing and keeps the bundled dates.
    func mayBeUnposted(pageAt index: Int) -> Bool {
        readsMonthlyPages || (self == .beaGDP && index > 0)
    }

    /// The pages to read at `now`. Fed minutes dates appear only on monthly calendar
    /// pages, which exist about two months ahead; a page not yet published is a 404.
    func urls(at now: Date) -> [URL] {
        switch self {
        case .fedMeetings:
            return [URL(string: "https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm")!]
        case .fedMinutes:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/New_York")!
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyy-MMMM"
            return (0...2).compactMap { offset in
                calendar.date(byAdding: .month, value: offset, to: now).flatMap {
                    URL(string: "https://www.federalreserve.gov/newsevents/\(formatter.string(from: $0).lowercased()).htm")
                }
            }
        case .beaPersonalIncome:
            return [URL(string: "https://apps.bea.gov/API/signup/release_dates.json")!]
        case .beaGDP:
            return [URL(string: "https://www.bea.gov/news/schedule/full")!,
                    URL(string: "https://www.bea.gov/news/schedule/next-year")!]
        case .censusRetail:
            return [URL(string: "https://www.census.gov/retail/release_schedule.html")!]
        case .ecb:
            return [URL(string: "https://www.ecb.europa.eu/press/calendars/mgcgc/html/index.en.html")!]
        case .boj:
            return [URL(string: "https://www.boj.or.jp/en/mopo/mpmsche_minu/index.htm")!]
        }
    }

    func parse(_ data: Data) -> [BundledEvent] {
        let page = String(decoding: data, as: UTF8.self)
        switch self {
        case .fedMeetings: return LiveEventParser.fomcMeetings(page)
        case .fedMinutes: return LiveEventParser.fomcMinutes(page)
        case .beaPersonalIncome: return LiveEventParser.personalIncome(data)
        case .beaGDP: return LiveEventParser.gdpAdvance(page)
        case .censusRetail: return LiveEventParser.retailSales(page)
        case .ecb: return LiveEventParser.ecb(page)
        case .boj: return LiveEventParser.boj(page)
        }
    }
}

/// Reads each publisher's page into bundled-file rows, at the times the Resources
/// README sets per kind. Only rows that match the page's known layout are read;
/// anything else is skipped rather than guessed.
enum LiveEventParser {
    /// Meeting second days from the per-year panels ("2027 FOMC Meetings"): month
    /// cells like "January" or "Jan/Feb", date cells like "26-27" or "31-1*".
    /// Notation votes and unscheduled meetings have other date text and are skipped.
    static func fomcMeetings(_ page: String) -> [BundledEvent] {
        let headings = page.matches(of: #/>(\d{4}) FOMC Meetings</a>/#)
        var events: [BundledEvent] = []
        for (index, heading) in headings.enumerated() {
            guard let year = Int(heading.output.1) else { continue }
            let end = index + 1 < headings.count ? headings[index + 1].range.lowerBound : page.endIndex
            let panel = page[heading.range.upperBound..<end]
            for row in panel.matches(of: #/fomc-meeting__month[^>]*><strong>([A-Za-z/]+)</strong></div>\s*<div class="fomc-meeting__date[^>]*>(\d{1,2})-(\d{1,2})\*?</div>/#) {
                let months = row.output.1.split(separator: "/")
                guard let first = months.first, let firstMonth = month(first),
                      let lastMonth = month(months.last ?? first),
                      let day = Int(row.output.3) else { continue }
                // A meeting spanning two months ends in the next year only for Dec/Jan.
                let endYear = lastMonth < firstMonth ? year + 1 : year
                events.append(.init(kind: .fomc, suffix: "fomc", year: endYear, month: lastMonth, day: day,
                                    time: "14:00", durationMinutes: 90, timeZone: "America/New_York"))
            }
        }
        return events
    }

    /// One monthly calendar page ("…/newsevents/2026-november.htm"): each FOMC Minutes
    /// entry's day number, in the page's month and year.
    static func fomcMinutes(_ page: String) -> [BundledEvent] {
        guard let title = page.firstMatch(of: #/<title>[^<]*?([A-Z][a-z]+) (\d{4})[^<]*</title>/#),
              let month = month(title.output.1), let year = Int(title.output.2) else { return [] }
        return page.matches(of: #/<p>FOMC Minutes</p>[\s\S]{0,400}?<div class="col-xs-3">\s*<p>(\d{1,2})</p>/#)
            .compactMap { Int($0.output.1) }
            .map {
                .init(kind: .fomcMinutes, suffix: "fomc-minutes", year: year, month: month, day: $0,
                      time: "14:00", durationMinutes: 30, timeZone: "America/New_York")
            }
    }

    /// BEA's release-dates file: "Personal Income and Outlays" timestamps in UTC,
    /// stored in New York time since some releases are at 10:00, not 08:30.
    static func personalIncome(_ data: Data) -> [BundledEvent] {
        guard let file = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let release = file["Personal Income and Outlays"] as? [String: Any],
              let dates = release["release_dates"] as? [String] else { return [] }
        let parser = ISO8601DateFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return dates.compactMap { parser.date(from: $0) }.map { date in
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return .init(kind: .pce, suffix: "pce", year: parts.year!, month: parts.month!, day: parts.day!,
                         time: String(format: "%02d:%02d", parts.hour!, parts.minute!),
                         durationMinutes: 1, timeZone: "America/New_York")
        }
    }

    /// BEA's schedule pages: rows titled "GDP (Advance Estimate)" (second and third
    /// estimates are other rows), dated in the table's "Year 2027" header year, at
    /// the row's own time.
    static func gdpAdvance(_ page: String) -> [BundledEvent] {
        guard let header = page.firstMatch(of: #/scope="col">Year (\d{4})</th>/#),
              let year = Int(header.output.1) else { return [] }
        return page.split(separator: "<tr").compactMap { row in
            guard let match = row.firstMatch(of: #/release-date">([A-Z][a-z]+) (\d{1,2})</div>\s*<small[^>]*>(\d{1,2}):(\d{2}) ([AP]M)</small>[\s\S]*?release-title[^>]*>\s*GDP \(Advance Estimate\)/#),
                  let month = month(match.output.1), let day = Int(match.output.2),
                  let hour = Int(match.output.3) else { return nil }
            let hour24 = hour % 12 + (match.output.5 == "PM" ? 12 : 0)
            return .init(kind: .gdp, suffix: "gdp-advance", year: year, month: month, day: day,
                         time: "\(String(format: "%02d", hour24)):\(match.output.4)",
                         durationMinutes: 1, timeZone: "America/New_York")
        }
    }

    /// The first table on Census's schedule ("Release Date at 8:30 am"), the advance
    /// monthly sales; later tables are other reports.
    static func retailSales(_ page: String) -> [BundledEvent] {
        guard let header = page.range(of: "Release Date at 8:30 am</strong>"),
              let tableEnd = page.range(of: "</table>", range: header.upperBound..<page.endIndex) else { return [] }
        return page[header.upperBound..<tableEnd.lowerBound]
            .matches(of: #/>([A-Z][a-z]+) (\d{1,2}), (\d{4})</#)
            .compactMap { row in
                guard let month = month(row.output.1), let day = Int(row.output.2), let year = Int(row.output.3) else {
                    return nil
                }
                return .init(kind: .retailSales, suffix: "retail-sales", year: year, month: month, day: day,
                             time: "08:30", durationMinutes: 1, timeZone: "America/New_York")
            }
    }

    /// Decision days are the "(Day 2), followed by press conference" entries; match
    /// that, since "non-monetary policy meeting" also contains "monetary policy meeting".
    static func ecb(_ page: String) -> [BundledEvent] {
        page.matches(of: #/<dt>\s*(\d{2})/(\d{2})/(\d{4})\s*</dt>\s*<dd>[^<]*\(Day 2\), followed by press conference/#)
            .compactMap { row in
                guard let day = Int(row.output.1), let month = Int(row.output.2), let year = Int(row.output.3) else {
                    return nil
                }
                return .init(kind: .ecb, suffix: "ecb", year: year, month: month, day: day,
                             time: "14:15", durationMinutes: 90, timeZone: "Europe/Berlin")
            }
    }

    /// Second meeting days from each "Table : 2027" schedule: first cells like
    /// "Mar. 17 (Wed.), 18 (Thurs.)" or "Apr. 30 (Thu.), May 1 (Fri.)", with line
    /// breaks inside cells. Meetings already held link to their statement
    /// ("<a …>Jan. 22 (Thurs.), 23 (Fri.) [PDF 171KB]</a>"), so tags and the bracketed
    /// size are dropped. The decision time is not published; 12:00 JST is stored.
    static func boj(_ page: String) -> [BundledEvent] {
        let captions = page.matches(of: #/Table : (\d{4})</caption>/#)
        var events: [BundledEvent] = []
        for caption in captions {
            guard let year = Int(caption.output.1),
                  let tableEnd = page.range(of: "</table>", range: caption.range.upperBound..<page.endIndex) else { continue }
            let table = page[caption.range.upperBound..<tableEnd.lowerBound]
            for row in table.matches(of: #/<tr>\s*<td>([\s\S]*?)</td>/#) {
                let cell = row.output.1.replacing(#/<[^>]*>|\[[^\]]*\]/#, with: "")
                    .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                guard let match = cell.wholeMatch(of: #/([A-Z][a-z]+)\.? (\d{1,2}) \([A-Za-z.]+\), (?:([A-Z][a-z]+)\.? )?(\d{1,2}) \([A-Za-z.]+\)/#),
                      let firstMonth = month(match.output.1), let day = Int(match.output.4) else { continue }
                let lastMonth = match.output.3.flatMap { month($0) } ?? firstMonth
                events.append(.init(kind: .boj, suffix: "boj", year: lastMonth < firstMonth ? year + 1 : year,
                                    month: lastMonth, day: day,
                                    time: "12:00", durationMinutes: 60, timeZone: "Asia/Tokyo"))
            }
        }
        return events
    }

    /// "January", "Jan", "Sept" or "June" to 1–12.
    private static func month(_ name: some StringProtocol) -> Int? {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return months.firstIndex(of: name.prefix(3).lowercased()).map { $0 + 1 }
    }
}

private extension BundledEvent {
    init(kind: EconomicEventKind, suffix: String, year: Int, month: Int, day: Int,
         time: String, durationMinutes: Int, timeZone: String) {
        let date = MarketExceptionIndex.key(year: year, month: month, day: day)
        self.init(id: "\(date)-\(suffix)", kind: kind, title: nil, date: date, time: time,
                  durationMinutes: durationMinutes, timeZone: timeZone)
    }
}

/// What one source last returned. `ranges` are the canonical-zone dates (inclusive,
/// "yyyy-MM-dd") the rows cover; inside them they replace the bundled dates of the
/// kind, outside them bundled dates stay.
struct LiveSourceResult: Codable, Equatable, Sendable {
    struct DayRange: Codable, Equatable, Sendable {
        let first: String
        let last: String
    }

    let source: LiveEventSource
    let events: [BundledEvent]
    let ranges: [DayRange]
}

/// The cache file: the latest good result per source and the last attempt.
struct LiveEventCache: Codable, Equatable, Sendable {
    var attemptedAt: Date?
    var results: [LiveSourceResult] = []
    /// Sources whose last attempt failed; their previous result, if any, is kept.
    var failures: [LiveEventSource] = []

    /// Weekly after a clean run, daily while any source is failing.
    func isDue(at now: Date) -> Bool {
        guard let attemptedAt else { return true }
        let wait: TimeInterval = failures.isEmpty ? 7 * 86_400 : 86_400
        return now.timeIntervalSince(attemptedAt) >= wait || now < attemptedAt
    }

    /// Bundled events with each source's rows swapped in over the dates it covers.
    func merged(into bundled: [EconomicEvent]) -> [EconomicEvent] {
        var events = bundled
        for result in results {
            let live = result.events.compactMap { try? EconomicEventCatalog.resolve($0) }
            func covered(_ event: EconomicEvent) -> Bool {
                let key = event.canonicalDateKey
                return result.ranges.contains { $0.first <= key && key <= $0.last }
            }
            events.removeAll { $0.kind == result.source.kind && covered($0) }
            let ids = Set(live.map(\.id))
            events.removeAll { ids.contains($0.id) }
            events += live.filter { $0.kind == result.source.kind && covered($0) }
        }
        return events.sorted(by: EconomicEventCatalog.eventOrder)
    }
}

protocol EventFetching: Sendable {
    /// The body and HTTP status of one GET.
    func fetch(_ url: URL) async throws -> (Data, Int)
}

/// Plain GETs with an honest User-Agent that carries no personal details, no
/// cookies and no cache. A 403 or bot check is a failure, never worked around.
struct URLSessionEventFetcher: EventFetching {
    private static let session = URLSession(configuration: .ephemeral)

    func fetch(_ url: URL) async throws -> (Data, Int) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("MarketSessions/1.0 (personal macOS app)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await Self.session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

/// Fetches every source, keeps the previous result for any that fails, and saves
/// the cache atomically.
struct LiveEventRefresher: Sendable {
    let fetcher: any EventFetching
    /// `live-events.json` in Application Support.
    let cacheURL: URL

    static func standard() -> LiveEventRefresher? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return LiveEventRefresher(
            fetcher: URLSessionEventFetcher(),
            cacheURL: support.appendingPathComponent("Market Sessions/live-events.json")
        )
    }

    func loadCache() -> LiveEventCache {
        (try? Data(contentsOf: cacheURL)).flatMap { try? JSONDecoder().decode(LiveEventCache.self, from: $0) }
            ?? LiveEventCache()
    }

    /// `bundled` is the shipped schedule, which each page's rows must account for.
    /// Sources are read side by side, so a stalled network holds a run for one
    /// timeout per Fed minutes page rather than one per GET. A run in which no source
    /// reached its server (the Mac is offline) is not an attempt: `previous` comes
    /// back unsaved and stays due.
    func run(at now: Date, previous: LiveEventCache, bundled: [EconomicEvent]) async -> LiveEventCache {
        let outcomes = await withTaskGroup(of: (LiveEventSource, Outcome).self) { group in
            for source in LiveEventSource.allCases {
                group.addTask { (source, await fetch(source, at: now, bundled: bundled)) }
            }
            return await group.reduce(into: [:]) { $0[$1.0] = $1.1 }
        }
        guard outcomes.values.contains(where: { $0 != .offline }) else { return previous }
        var cache = LiveEventCache(attemptedAt: now)
        for source in LiveEventSource.allCases {
            if case .read(let result) = outcomes[source] {
                cache.results.append(result)
            } else {
                cache.failures.append(source)
                if let old = previous.results.first(where: { $0.source == source }) {
                    cache.results.append(old)
                }
            }
        }
        save(cache)
        return cache
    }

    private enum Outcome: Equatable, Sendable {
        case read(LiveSourceResult)
        case failed
        /// The first GET found no connection.
        case offline
    }

    /// Failed when a page fails, reads as too few dates, misses a bundled date, or
    /// repeats an ID. A minutes page that is not published yet (404) or lists no
    /// minutes covers nothing, so its month keeps the bundled dates.
    private func fetch(_ source: LiveEventSource, at now: Date, bundled: [EconomicEvent]) async -> Outcome {
        var events: [BundledEvent] = []
        var ranges: [LiveSourceResult.DayRange] = []
        for (index, url) in source.urls(at: now).enumerated() {
            let response: (Data, Int)
            do {
                response = try await fetcher.fetch(url)
            } catch let error as URLError where index == 0 && Self.offlineCodes.contains(error.code) {
                return .offline
            } catch {
                return .failed
            }
            let (data, status) = response
            let mayBeUnposted = source.mayBeUnposted(pageAt: index)
            if mayBeUnposted, status == 404 { continue }
            guard status == 200 else { return .failed }
            let rows = source.parse(data)
            let range: LiveSourceResult.DayRange
            if source.readsMonthlyPages {
                guard let month = rows.first.map({ String($0.date.prefix(7)) }) else { continue }
                range = .init(first: "\(month)-01", last: "\(month)-31")
            } else {
                if mayBeUnposted, rows.count < source.minimumCount { continue }
                guard rows.count >= source.minimumCount,
                      let first = rows.map(\.date).min(), let last = rows.map(\.date).max() else { return .failed }
                range = .init(first: first, last: last)
            }
            guard Self.rows(rows, accountFor: bundled.filter { $0.kind == source.kind }, in: range) else { return .failed }
            ranges.append(range)
            events += rows
        }
        guard !source.readsMonthlyPages || !events.isEmpty,
              Set(events.map(\.id)).count == events.count else { return .failed }
        return .read(LiveSourceResult(source: source, events: events, ranges: ranges))
    }

    /// Errors that mean this Mac has no connection rather than that a publisher failed.
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .dnsLookupFailed,
    ]

    /// Inside its range a page replaces the bundled dates, so each bundled date needs a
    /// fetched one within two weeks. One missing means a row the parser skipped (the
    /// page changed), not a cancelled release; publishers move dates by days, not weeks.
    private static func rows(_ rows: [BundledEvent], accountFor bundled: [EconomicEvent],
                             in range: LiveSourceResult.DayRange) -> Bool {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withFullDate]
        let fetched = rows.compactMap { parser.date(from: $0.date) }
        return bundled.allSatisfy { event in
            let key = event.canonicalDateKey
            guard range.first <= key, key <= range.last, let day = parser.date(from: key) else { return true }
            return fetched.contains { abs($0.timeIntervalSince(day)) <= 14 * 86_400 }
        }
    }

    private func save(_ cache: LiveEventCache) {
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder().encode(cache).write(to: cacheURL, options: .atomic)
        } catch {
            // The merged dates still apply for this run; the next launch refetches.
        }
    }
}
