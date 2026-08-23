import SwiftUI

struct FocusSessionCard: View {
    let focus: FocusSession?
    let now: Date
    let displayTimeZone: TimeZone

    var body: some View {
        Group {
            if let focus {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Label(focus.sessionName, systemImage: focus.iconName)
                            .font(.headline)
                        Spacer(minLength: 8)
                        Text(focus.statusLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor(for: focus))
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text(focus.actionLabel)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(focus.countdownText)
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                    }

                    ProgressView(value: focus.progress)
                        .accessibilityLabel("Session progress")
                        .accessibilityValue(
                            Text(focus.progress, format: .percent.precision(.fractionLength(0)))
                        )

                    Text(
                        MarketDateFormatting.transition(
                            focus.transitionDate,
                            relativeTo: now,
                            timeZone: displayTimeZone
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "Schedule unavailable",
                    systemImage: "clock.badge.exclamationmark",
                    description: Text("Market times could not be resolved.")
                )
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statusColor(for focus: FocusSession) -> Color {
        switch focus.mode {
        case .active:
            .green
        case .upcoming:
            .secondary
        case .fallback:
            .blue
        }
    }
}
