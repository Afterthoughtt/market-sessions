import SwiftUI

/// "Upcoming Events" — the next tier-1 U.S. economic events, rolling forward so
/// the section is never empty. Each row is the event name, its local day and
/// time, and a countdown until it goes live ("Live" while the release window is
/// open). Capped at four rows with a disclosure for the rest.
struct EconomicEventsSection: View {
    let upcoming: UpcomingEconomicEvents
    let now: Date
    let displayTimeZone: TimeZone
    let palette: MarketPalette

    @State private var isExpanded = false

    private static let collapsedRowCap = 4

    var body: some View {
        let events = upcoming.events
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Upcoming Events")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.sec)
                Text("\(events.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.faint)
                Spacer(minLength: 0)
                if events.count > Self.collapsedRowCap {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        HStack(spacing: 3) {
                            if !isExpanded {
                                Text("+\(events.count - Self.collapsedRowCap) more")
                            }
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(palette.faint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Show fewer events" : "Show all events")
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 2)

            let displayed = isExpanded ? events : Array(events.prefix(Self.collapsedRowCap))
            ForEach(displayed) { event in
                eventRow(event)
                if event.id != displayed.last?.id {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(height: 1)
                }
            }

            if let notice = stalenessNotice {
                Text(notice)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.faint)
                    .padding(.top, events.isEmpty ? 2 : 6)
                    .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    /// Shown once the resolver can no longer fill its minimum from the bundled
    /// catalog — the schedule running out should be visible, not silent.
    private var stalenessNotice: String? {
        guard upcoming.events.count < 4, let scheduleEnd = upcoming.scheduleEnd else { return nil }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = displayTimeZone
        formatter.dateFormat = "MMM d, yyyy"
        return "Bundled schedule ends \(formatter.string(from: scheduleEnd))"
    }

    private func eventRow(_ event: EconomicEvent) -> some View {
        HStack(alignment: .center, spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Text(scheduleLabel(event))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(palette.sec)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            countdownLabel(event)
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(event))
    }

    @ViewBuilder
    private func countdownLabel(_ event: EconomicEvent) -> some View {
        if event.phase(at: now) == .live {
            Text("Live")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.green)
        } else if let minutes = event.remainingMinutes(at: now) {
            Text("in \(MarketDurationFormatting.compact(minutes: minutes))")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(palette.accent)
        }
    }

    /// "Today · 5:30 AM PDT", "Fri · 5:30 AM PDT" within the week, "Fri Sep 4 · 5:30 AM PST" beyond.
    private func scheduleLabel(_ event: EconomicEvent) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = displayTimeZone

        let day: String
        if calendar.isDate(event.start, inSameDayAs: now) {
            day = "Today"
        } else {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.timeZone = displayTimeZone
            let daysAway = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: calendar.startOfDay(for: event.start)
            ).day ?? 0
            formatter.dateFormat = daysAway < 7 ? "EEE" : "EEE MMM d"
            day = formatter.string(from: event.start)
        }
        let zone = displayTimeZone.abbreviation(for: event.start) ?? displayTimeZone.identifier
        return "\(day) · \(MarketDateFormatting.time(event.start, timeZone: displayTimeZone)) \(zone)"
    }

    private func accessibilityLabel(_ event: EconomicEvent) -> String {
        var label = "\(event.displayTitle), \(scheduleLabel(event))"
        if event.phase(at: now) == .live {
            label += ", live now"
        } else if let minutes = event.remainingMinutes(at: now) {
            label += ", in " + MarketDurationFormatting.spoken(minutes: minutes)
        }
        return label
    }
}
