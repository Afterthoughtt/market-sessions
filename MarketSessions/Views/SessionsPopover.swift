import SwiftUI

/// The compact menu-bar popover from the final design handoff.
struct SessionsPopover: View {
    let model: MarketSessionsModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: MarketPalette { .palette(for: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            header

            if model.orderedSessions.isEmpty {
                Text("Choose markets in Settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.sec)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                sectionHeader("Open")
                if openSessions.isEmpty {
                    Text("No markets open")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.sec)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                sessionRows(openSessions) { resolved in
                    OpenSessionRow(
                        resolved: resolved,
                        now: model.now,
                        displayTimeZone: model.displayTimeZone,
                        palette: palette
                    )
                }

                if !breakSessions.isEmpty {
                    sectionHeader("Break")
                    sessionRows(breakSessions) { resolved in
                        ClosedSessionRow(
                            resolved: resolved,
                            now: model.now,
                            displayTimeZone: model.displayTimeZone,
                            palette: palette
                        )
                    }
                }

                if !closedSessions.isEmpty {
                    sectionHeader("Closed")
                    sessionRows(closedSessions) { resolved in
                        ClosedSessionRow(
                            resolved: resolved,
                            now: model.now,
                            displayTimeZone: model.displayTimeZone,
                            palette: palette
                        )
                    }
                }
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
                    .font(.system(size: 11))
                    .foregroundStyle(palette.sec)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }

            Rectangle()
                .fill(palette.dividerStrong)
                .frame(height: 1)
                .padding(.horizontal, -14)

            SettingsLink {
                Text("Settings…")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            }
            .buttonStyle(PopoverRowButtonStyle(palette: palette))
            .keyboardShortcut(",")
        }
        .padding(.top, 14)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .frame(width: 340)
        .task {
            model.start()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Market Sessions")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.15)
                    .foregroundStyle(palette.text)

                Text(weekday)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.sec)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(model.preferences.timeZoneIdentifier == nil ? "Your time" : "Time") · \(timeZoneAbbreviation)")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.sec)

                Text(
                    "Daily Close in \(Text(MarketDurationFormatting.compact(minutes: model.utcDayRemainingMinutes)).fontWeight(.semibold).foregroundColor(palette.text))"
                )
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(palette.sec)
                .accessibilityLabel(
                    "UTC daily close in "
                        + MarketDurationFormatting.spoken(minutes: model.utcDayRemainingMinutes)
                )
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.sec)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 2)
    }

    private func sessionRows<Row: View>(
        _ sessions: [ResolvedSession],
        @ViewBuilder row: @escaping (ResolvedSession) -> Row
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(sessions) { resolved in
                row(resolved)

                if resolved.id != sessions.last?.id {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(height: 1)
                }
            }
        }
    }

    private var openSessions: [ResolvedSession] {
        model.orderedSessions
            .filter { $0.status.isActive }
            .sorted(by: transitionComesFirst)
    }

    private var closedSessions: [ResolvedSession] {
        model.orderedSessions
            .filter { $0.status == .closed }
            .sorted(by: transitionComesFirst)
    }

    private var breakSessions: [ResolvedSession] {
        model.orderedSessions
            .filter { $0.status == .onBreak }
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
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = model.displayTimeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: model.now)
    }

    private var timeZoneAbbreviation: String {
        model.displayTimeZone.abbreviation(for: model.now)
            ?? model.displayTimeZone.identifier
    }

    /// The streamlined popover only surfaces holiday coverage once it needs attention.
    private var hoursWarning: String? {
        guard let coverage = model.exceptionCoverageEnd else {
            return "Recurring hours only"
        }
        guard model.now > coverage else { return nil }

        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = model.displayTimeZone
        formatter.dateFormat = "MMM yyyy"
        return "Holiday data ended \(formatter.string(from: coverage))"
    }
}

/// Menu-row affordance for full-width popover actions: a rounded highlight on
/// hover, slightly stronger while pressed, drawn in the neutral palette.
private struct PopoverRowButtonStyle: ButtonStyle {
    let palette: MarketPalette
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? palette.ringTrack : (isHovering ? palette.track : .clear))
            )
            .padding(.horizontal, -8)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.1), value: isHovering)
    }
}
