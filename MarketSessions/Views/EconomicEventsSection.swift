import SwiftUI

/// "This week" — tier-1 U.S. economic events for the current Monday–Friday,
/// capped at four rows with a disclosure for the rest. Times show in the event's
/// canonical zone (ET for U.S. releases) and converted to local; the next event
/// carries a countdown, and a live event is flagged.
struct EconomicEventsSection: View {
    let weekly: WeeklyEconomicEvents
    let now: Date
    let displayTimeZone: TimeZone
    let palette: MarketPalette

    @State private var isExpanded = false

    private static let collapsedRowCap = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("This week")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.sec)
                Text("\(weekly.events.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.faint)
                Spacer(minLength: 0)
                if weekly.events.count > Self.collapsedRowCap {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        HStack(spacing: 3) {
                            if !isExpanded {
                                Text("+\(weekly.events.count - Self.collapsedRowCap) more")
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
            .padding(.bottom, 4)

            ForEach(displayedEvents) { event in
                eventRow(event)
                if event.id != displayedEvents.last?.id {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(height: 1)
                        .padding(.leading, 34)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private var displayedEvents: [EconomicEvent] {
        isExpanded ? weekly.events : Array(weekly.events.prefix(Self.collapsedRowCap))
    }

    private func eventRow(_ event: EconomicEvent) -> some View {
        let phase = event.phase(at: now)
        let isNext = event.id == weekly.nextEventID

        return HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(weekdayLabel(event))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.22)
                .foregroundStyle(palette.sec)
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.kind.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(phase == .past ? palette.faint : palette.text)
                    .lineLimit(1)
                Text(timesLabel(event))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(phase == .past ? palette.faint : palette.sec)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            trailingLabel(event, phase: phase, isNext: isNext)
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(event, phase: phase, isNext: isNext))
    }

    @ViewBuilder
    private func trailingLabel(_ event: EconomicEvent, phase: EconomicEvent.Phase, isNext: Bool) -> some View {
        switch phase {
        case .live:
            Text("Live")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.green)
        case .upcoming where isNext:
            if let minutes = event.remainingMinutes(at: now) {
                Text("in \(MarketDurationFormatting.compact(minutes: minutes))")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.accent)
            }
        case .past:
            Text("Done")
                .font(.system(size: 11))
                .foregroundStyle(palette.faint)
        default:
            EmptyView()
        }
    }

    private func weekdayLabel(_ event: EconomicEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = displayTimeZone
        formatter.dateFormat = "EEE"
        return formatter.string(from: event.start)
    }

    private func timesLabel(_ event: EconomicEvent) -> String {
        let canonicalZone = event.canonicalTimeZone
        let canonical = MarketDateFormatting.time(event.start, timeZone: canonicalZone)
        let local = MarketDateFormatting.time(event.start, timeZone: displayTimeZone)
        let canonicalAbbr = canonicalZone.identifier == "America/New_York"
            ? "ET"
            : canonicalZone.abbreviation(for: event.start) ?? canonicalZone.identifier
        let localAbbr = displayTimeZone.abbreviation(for: event.start) ?? displayTimeZone.identifier
        return "\(canonical) \(canonicalAbbr) · \(local) \(localAbbr)"
    }

    private func accessibilityLabel(_ event: EconomicEvent, phase: EconomicEvent.Phase, isNext: Bool) -> String {
        var label = "\(event.kind.title), \(weekdayLabel(event)), \(timesLabel(event))"
        switch phase {
        case .live:
            label += ", live now"
        case .upcoming where isNext:
            if let minutes = event.remainingMinutes(at: now) {
                label += ", in " + MarketDurationFormatting.spoken(minutes: minutes)
            }
        case .past:
            label += ", done"
        default:
            break
        }
        return label
    }
}
