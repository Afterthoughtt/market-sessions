import Foundation

/// One local notification the app wants delivered; identifiers are deterministic
/// so a replan can diff against what is already pending.
struct PlannedNotification: Hashable, Sendable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

/// Deterministic schedule for market and event notifications. Markets notify at
/// the first open and final close of each trading day in the canonical zone
/// (lunch recesses and CME's daily maintenance gap stay quiet); events notify at
/// their scheduled start. Both fire `leadMinutes` early.
struct NotificationPlanner: Sendable {
    static let leadOptions = [0, 5, 15, 30]
    /// UNUserNotificationCenter keeps at most 64 pending requests per app.
    static let pendingLimit = 60

    func plan(
        sessions: [MarketSession],
        events: [EconomicEvent],
        leadMinutes: Int,
        at now: Date,
        resolver: SessionResolver,
        displayTimeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> [PlannedNotification] {
        let lead = TimeInterval(max(0, leadMinutes) * 60)
        var planned: [PlannedNotification] = []

        for session in sessions {
            let active = resolver.occurrences(for: session, around: now).filter(\.kind.countsAsActive)
            for cycle in Dictionary(grouping: active, by: \.anchorDate).values {
                guard let start = cycle.map(\.start).min(), let end = cycle.map(\.end).max() else { continue }
                for (verb, boundary) in [(SessionTransition.Verb.opens, start), (.closes, end)] {
                    let clock = MarketDateFormatting.time(boundary, timeZone: displayTimeZone, locale: locale)
                    planned.append(PlannedNotification(
                        id: "market.\(session.id.rawValue).\(verb.rawValue.lowercased()).\(Int(boundary.timeIntervalSince1970))",
                        title: session.name,
                        body: leadMinutes > 0
                            ? "\(verb.rawValue) in \(MarketDurationFormatting.spoken(minutes: leadMinutes)), at \(clock)"
                            : "\(verb.rawValue) at \(clock)",
                        fireDate: boundary.addingTimeInterval(-lead)
                    ))
                }
            }
        }

        for event in events {
            let clock = MarketDateFormatting.time(event.start, timeZone: displayTimeZone, locale: locale)
            let approximate = event.kind.hasApproximateTime ? " (approx.)" : ""
            planned.append(PlannedNotification(
                id: "event.\(event.id)",
                title: event.compactTitle,
                body: leadMinutes > 0
                    ? "In \(MarketDurationFormatting.spoken(minutes: leadMinutes)), at \(clock)\(approximate)"
                    : "Scheduled for \(clock)\(approximate)",
                fireDate: event.start.addingTimeInterval(-lead)
            ))
        }

        return Array(
            planned
                .filter { $0.fireDate > now }
                .sorted { lhs, rhs in
                    lhs.fireDate == rhs.fireDate ? lhs.id < rhs.id : lhs.fireDate < rhs.fireDate
                }
                .prefix(Self.pendingLimit)
        )
    }
}
