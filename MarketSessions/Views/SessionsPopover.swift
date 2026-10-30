import AppKit
import SwiftUI

/// The compact menu-bar popover from the final design handoff.
struct SessionsPopover: View {
    let model: MarketSessionsModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings

    private var palette: MarketPalette { .palette(for: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            header

            if model.orderedSessions.isEmpty {
                Text("Choose markets in Settings.")
                    .font(.body)
                    .foregroundStyle(palette.sec)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                ForEach(
                    [SessionStatus.open, .preMarket, .postMarket, .holiday, .closed],
                    id: \.self
                ) { status in
                    let sessions = sessions(status)
                    if !sessions.isEmpty {
                        sectionHeader(status.label, color: palette.stateColor(status))
                        sessionRows(sessions)
                    }
                }
            }

            if !model.upcomingClosures.closures.isEmpty {
                closuresSection
            }

            if !model.preferences.eventKinds.isEmpty {
                EconomicEventsSection(
                    upcoming: model.upcomingEvents,
                    now: model.now,
                    displayTimeZone: model.displayTimeZone,
                    palette: palette
                )
            }

            if let hoursWarning {
                Text(hoursWarning)
                    .font(.subheadline)
                    .foregroundStyle(palette.sec)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }

            // The kit's menu separator: a 1pt line 5pt below the last item.
            Rectangle()
                .fill(palette.separator)
                .frame(height: 1)
                .padding(.horizontal, -14)
                .padding(.top, 5)

            // Agent apps are not active while the popover is up, so a bare
            // SettingsLink opens the window behind everything or not at all.
            Button {
                NSApp.activate()
                openSettings()
            } label: {
                Text("Settings…")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(PopoverRowButtonStyle(palette: palette))
        }
        .padding(.top, 14)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .frame(width: 340)
        .task {
            model.start()
        }
        .onAppear { model.setLiveSurface("popover", visible: true) }
        .onDisappear { model.setLiveSurface("popover", visible: false) }
    }

    private var header: some View {
        // Daily Close sits on the weekday's baseline; an overridden zone, when set, rides above it.
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Market Sessions")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)

                Text(weekday)
                    .font(.body)
                    .foregroundStyle(palette.sec)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                // The system zone needs no label; an override does, or its times would read as local.
                if model.preferences.timeZoneIdentifier != nil {
                    Text("Time · \(timeZoneAbbreviation)")
                        .font(.subheadline)
                        .foregroundStyle(palette.sec)
                }

                Text(
                    "Daily Close in \(Text(MarketDurationFormatting.compact(minutes: model.utcDayRemainingMinutes)).fontWeight(.semibold).foregroundColor(palette.text))"
                )
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(palette.sec)
                .accessibilityLabel(
                    "UTC daily close in "
                        + MarketDurationFormatting.spoken(minutes: model.utcDayRemainingMinutes)
                )
                .help("Time left until the daily close at midnight UTC")
            }
        }
    }

    /// Holidays and early closes in the coming week, in the Upcoming Events row style.
    /// Holidays are calendar days in the market's own zone; early closes are instants
    /// shown in the display zone like every other time.
    private var closuresSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Closures", color: palette.sec)

            // Every closure in the week, uncapped (owner decision 2026-10-30): Christmas week
            // with all six markets runs to nine rows rather than hiding Christmas Day.
            ForEach(model.upcomingClosures.closures) { closure in
                let label = closureLabel(closure)
                let day = MarketDateFormatting.day(closure.date, timeZone: closure.dayTimeZone)
                let details = closureDetails(closure, day: day)
                HStack(spacing: 10) {
                    Text(label)
                        .font(.body)
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    Text(day)
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(palette.sec)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(height: 24)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(details)
                .help(details)
            }
        }
    }

    private func closureLabel(_ closure: MarketClosure) -> String {
        switch closure.exception.kind {
        case .holiday:
            "\(closure.session.name) · \(closure.exception.name ?? "closed")"
        case .earlyClose:
            "\(closure.session.name) · closes \(MarketDateFormatting.time(closure.date, timeZone: model.displayTimeZone))"
        }
    }

    private func closureDetails(_ closure: MarketClosure, day: String) -> String {
        switch closure.exception.kind {
        case .holiday:
            let name = closure.exception.name.map { " for \($0)" } ?? ""
            return "\(closure.session.name) closed\(name), \(day)"
        case .earlyClose:
            let when = MarketDateFormatting.dateTime(closure.date, dateStyle: .full, timeZone: model.displayTimeZone)
            // A half day shown in the display zone can land on another date (Hong Kong's
            // Christmas Eve noon is 11 PM the day before in New York), so add the market's own time.
            let marketZone = closure.session.canonicalTimeZone
            guard marketZone.secondsFromGMT(for: closure.date) != model.displayTimeZone.secondsFromGMT(for: closure.date) else {
                return "\(closure.session.name) closes early, \(when)"
            }
            let local = MarketDateFormatting.dateTime(closure.date, dateStyle: .medium, timeZone: marketZone)
            let city = marketZone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? marketZone.identifier
            return "\(closure.session.name) closes early, \(when) (\(local) in \(city))"
        }
    }

    private func sectionHeader(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
        .padding(.bottom, 2)
        .accessibilityAddTraits(.isHeader)
    }

    /// Rows sit together like menu items; section headers and spacing do the grouping.
    private func sessionRows(_ sessions: [ResolvedSession]) -> some View {
        VStack(spacing: 0) {
            ForEach(sessions) { resolved in
                SessionRow(
                    resolved: resolved,
                    now: model.now,
                    displayTimeZone: model.displayTimeZone,
                    palette: palette
                )
            }
        }
    }

    private func sessions(_ status: SessionStatus) -> [ResolvedSession] {
        model.orderedSessions
            .filter { $0.status == status }
            .sorted(by: transitionComesFirst)
    }

    private func transitionComesFirst(_ lhs: ResolvedSession, _ rhs: ResolvedSession) -> Bool {
        let lhsDate = lhs.transition?.date ?? .distantFuture
        let rhsDate = rhs.transition?.date ?? .distantFuture
        if lhsDate == rhsDate {
            return lhs.session.focusPriority < rhs.session.focusPriority
        }
        return lhsDate < rhsDate
    }

    private var weekday: String {
        model.now.formatted(Date.FormatStyle(timeZone: model.displayTimeZone).weekday(.wide))
    }

    private var timeZoneAbbreviation: String {
        model.displayTimeZone.abbreviation(for: model.now)
            ?? model.displayTimeZone.identifier
    }

    /// The streamlined popover only surfaces holiday coverage once it needs attention:
    /// after it ends, or as soon as a shown open or close falls past it.
    private var hoursWarning: String? {
        guard let coverage = model.exceptionCoverageEnd else {
            return "Recurring hours only"
        }
        // Coverage is the file's last date at 23:59 UTC; format it in UTC so a zone
        // ahead of UTC does not show the following day.
        let date = coverage.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: TimeZone(identifier: "UTC") ?? .gmt)
        )
        if model.now > coverage {
            return "Holiday data ended \(date)"
        }
        if model.transitionsPassHolidayCoverage || model.upcomingClosures.passesCoverage {
            return "Holiday data ends \(date); later times assume regular hours"
        }
        return nil
    }
}

/// Menu-item hover highlight per Apple's macOS 27 UI kit (Menus, menu item in its
/// Hover state): 24pt row, 8pt continuous corner radius, highlight extending 7pt
/// past the text inset on both sides, accent fill with a white label (the kit draws
/// the default accent; this follows the user's). Padded to the 32pt footer row.
/// The highlight also shows while pressed and under keyboard focus, as a menu item's does.
private struct PopoverRowButtonStyle: ButtonStyle {
    let palette: MarketPalette

    func makeBody(configuration: Configuration) -> some View {
        PopoverRow(configuration: configuration, palette: palette)
    }
}

private struct PopoverRow: View {
    let configuration: ButtonStyleConfiguration
    let palette: MarketPalette
    @Environment(\.isFocused) private var isFocused
    @State private var isHovering = false

    var body: some View {
        let isHighlighted = isHovering || isFocused || configuration.isPressed
        configuration.label
            .foregroundStyle(isHighlighted ? Color.white : palette.text)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .padding(.horizontal, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHighlighted ? Color.accentColor : .clear)
            )
            .padding(.horizontal, -7)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
    }
}
