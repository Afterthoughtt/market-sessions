import SwiftUI

/// The next four configured economic events, presented as a plain macOS list.
struct EconomicEventsSection: View {
    let upcoming: UpcomingEconomicEvents
    let now: Date
    let displayTimeZone: TimeZone
    let palette: MarketPalette

    private static let rowCap = 4

    private var displayedEvents: [EconomicEvent] {
        Array(upcoming.events.prefix(Self.rowCap))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Upcoming events")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.sec)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
                .padding(.bottom, 2)

            ForEach(displayedEvents) { event in
                eventRow(event)

                if event.id != displayedEvents.last?.id {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(height: 1)
                }
            }

            if displayedEvents.isEmpty {
                Text("No upcoming events in the bundled schedule.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.sec)
                    .padding(.vertical, 8)
            }
        }
    }

    private func eventRow(_ event: EconomicEvent) -> some View {
        HStack(spacing: 10) {
            Text(event.compactTitle)
                .font(.system(size: 13))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 6)

            Text(eventLabel(event))
                .font(.system(size: 11, weight: isImminent(event) ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(isImminent(event) ? palette.text : palette.sec)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(eventDetails(event).replacingOccurrences(of: "≈", with: "approximately "))
        .help(eventDetails(event))
    }

    private func isImminent(_ event: EconomicEvent) -> Bool {
        if event.phase(at: now) == .live { return true }
        let interval = event.start.timeIntervalSince(now)
        return interval >= 0 && interval < 24 * 60 * 60
    }

    private func eventLabel(_ event: EconomicEvent) -> String {
        if event.phase(at: now) == .live {
            return "Live"
        }

        if isImminent(event) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = displayTimeZone

            let day: String
            if calendar.isDate(event.start, inSameDayAs: now) {
                day = "Today"
            } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                      calendar.isDate(event.start, inSameDayAs: tomorrow) {
                day = "Tomorrow"
            } else {
                let formatter = DateFormatter()
                formatter.locale = .autoupdatingCurrent
                formatter.timeZone = displayTimeZone
                formatter.dateFormat = "EEE"
                day = formatter.string(from: event.start)
            }
            let approximation = event.kind == .boj ? "≈" : ""
            return "\(day) \(approximation)\(MarketDateFormatting.time(event.start, timeZone: displayTimeZone))"
        }

        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = displayTimeZone
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: event.start)
    }

    private func eventDetails(_ event: EconomicEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = displayTimeZone
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        let zone = displayTimeZone.abbreviation(for: event.start) ?? displayTimeZone.identifier
        let approximation = event.kind == .boj ? " (approximate announcement time)" : ""
        let live = event.phase(at: now) == .live ? " · Live" : ""
        return "\(event.displayTitle) · \(formatter.string(from: event.start)) \(zone)\(approximation)\(live)"
    }
}
