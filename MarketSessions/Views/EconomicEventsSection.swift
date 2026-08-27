import SwiftUI

/// "Upcoming Events" — tier-1 U.S. economic events remaining in the current
/// Monday–Friday. Past events are dropped; each row is the event name, its local
/// day and time, and a countdown until it goes live ("Live" while the release
/// window is open). Capped at four rows with a disclosure for the rest.
struct EconomicEventsSection: View {
    let weekly: WeeklyEconomicEvents
    let now: Date
    let displayTimeZone: TimeZone
    let palette: MarketPalette

    @State private var isExpanded = false

    private static let collapsedRowCap = 4

    /// Events still ahead (or live) this week — the section hides when this is empty.
    var upcomingEvents: [EconomicEvent] {
        weekly.events.filter { $0.end > now }
    }

    var body: some View {
        let events = upcomingEvents
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
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private func eventRow(_ event: EconomicEvent) -> some View {
        HStack(alignment: .center, spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.kind.title)
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

    /// "Wed · 5:30 AM" in the user's zone.
    private func scheduleLabel(_ event: EconomicEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = displayTimeZone
        formatter.dateFormat = "EEE"
        let weekday = formatter.string(from: event.start)
        return "\(weekday) · \(MarketDateFormatting.time(event.start, timeZone: displayTimeZone))"
    }

    private func accessibilityLabel(_ event: EconomicEvent) -> String {
        var label = "\(event.kind.title), \(scheduleLabel(event))"
        if event.phase(at: now) == .live {
            label += ", live now"
        } else if let minutes = event.remainingMinutes(at: now) {
            label += ", in " + MarketDurationFormatting.spoken(minutes: minutes)
        }
        return label
    }
}
