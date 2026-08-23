import SwiftUI

struct SessionRow: View {
    let resolved: ResolvedSession
    let isExpanded: Bool
    let now: Date
    let displayTimeZone: TimeZone
    let toggleExpansion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: toggleExpansion) {
                HStack(spacing: 10) {
                    Image(systemName: resolved.session.iconName)
                        .frame(width: 18)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(resolved.session.shortName)
                            .font(.body.weight(.medium))
                            .lineLimit(1)

                        if let transition = resolved.transition {
                            Text(
                                "\(transition.kind.rawValue) \(MarketDateFormatting.transition(transition.date, relativeTo: now, timeZone: displayTimeZone))"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    Text(resolved.status.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(isExpanded ? "Collapses session details" : "Expands session details")

            if isExpanded {
                SessionDetail(
                    resolved: resolved,
                    now: now,
                    displayTimeZone: displayTimeZone
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 7)
        .animation(.easeInOut(duration: 0.16), value: isExpanded)
    }

    private var statusColor: Color {
        switch resolved.status {
        case .active:
            .green
        case .recess, .maintenance, .informational:
            .orange
        case .closed:
            .secondary
        }
    }

    private var accessibilityLabel: String {
        var value = "\(resolved.session.name), \(resolved.status.label)"
        if let transition = resolved.transition {
            value += ", \(transition.kind.rawValue) \(MarketDateFormatting.transition(transition.date, relativeTo: now, timeZone: displayTimeZone))"
        }
        return value
    }
}
