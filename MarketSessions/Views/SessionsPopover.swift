import AppKit
import SwiftUI

/// The 390×590 popover — five fixed regions: header, divider, list label, list, footer.
struct SessionsPopover: View {
    let model: MarketSessionsModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: MarketPalette { .palette(for: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(palette.dividerStrong)
                .frame(height: 1)

            listLabel

            sessionList

            if model.weeklyEvents.events.contains(where: { $0.end > model.now }) {
                Rectangle()
                    .fill(palette.dividerStrong)
                    .frame(height: 1)

                EconomicEventsSection(
                    weekly: model.weeklyEvents,
                    now: model.now,
                    displayTimeZone: model.displayTimeZone,
                    palette: palette
                )
            }

            Rectangle()
                .fill(palette.dividerStrong)
                .frame(height: 1)

            footer
        }
        .frame(width: 390)
        .background(palette.popover)
        .task {
            model.start()
        }
    }

    // MARK: Region A — header

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                Text("Market Sessions")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.15)
                    .foregroundStyle(palette.text)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Your time · \(timeZoneAbbreviation)")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.sec)

                    HStack(spacing: 5) {
                        ProgressRing(
                            fraction: model.utcDayRemainingFraction,
                            size: 13,
                            lineWidth: 2,
                            track: palette.ringTrack,
                            arc: palette.accent
                        )
                        Text(
                            "\(Text("Daily Close in").foregroundColor(palette.sec)) \(Text(MarketDurationFormatting.compact(minutes: model.utcDayRemainingMinutes)).fontWeight(.medium).foregroundColor(palette.text))"
                        )
                        .font(.system(size: 10))
                        .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "UTC daily close in "
                            + MarketDurationFormatting.spoken(minutes: model.utcDayRemainingMinutes)
                    )
                }
            }

            sectionLabel

            OpenNowGrid(
                focus: model.focus,
                now: model.now,
                displayTimeZone: model.displayTimeZone,
                palette: palette
            )
        }
        .padding(.top, 14)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var sectionLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if model.focus.hero != nil {
                Text("Open now")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.sec)
                Text("\(model.focus.openEntries.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.faint)
            } else {
                Text("Next open")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.sec)
                Text("nothing trading")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.faint)
            }
        }
    }

    // MARK: Region C — list label

    private var listLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("All sessions")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.sec)
            Text("re-sorts at each open or close")
                .font(.system(size: 10))
                .foregroundStyle(palette.faint)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    // MARK: Region D — session list

    private var sessionList: some View {
        VStack(spacing: 0) {
            ForEach(model.orderedSessions) { resolved in
                SessionRow(
                    resolved: resolved,
                    now: model.now,
                    displayTimeZone: model.displayTimeZone,
                    palette: palette
                )

                if resolved.id != model.orderedSessions.last?.id {
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

    // MARK: Region E — footer

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 9, weight: .medium))
                Text("Recurring hours only")
                    .font(.system(size: 10))
            }
            .foregroundStyle(palette.sec)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { model.loginItemState.isEnabled },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            .toggleStyle(.checkbox)
            .font(.system(size: 11))
            .foregroundStyle(palette.text)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .controlSize(.small)
            .font(.system(size: 11))
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
    }

    private var timeZoneAbbreviation: String {
        model.displayTimeZone.abbreviation(for: model.now)
            ?? model.displayTimeZone.identifier
    }
}
