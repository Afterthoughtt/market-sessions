import SwiftUI

/// Region D row — static text, no hover, no click, no expansion.
/// Columns: code 34 / name / spacer / state 72 / transition 114.
struct SessionRow: View {
    let resolved: ResolvedSession
    let now: Date
    let displayTimeZone: TimeZone
    let palette: MarketPalette

    var body: some View {
        HStack(spacing: 9) {
            Text(resolved.session.code)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.22)
                .foregroundStyle(palette.sec)
                .frame(width: 34, alignment: .leading)

            Text(resolved.session.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.text)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 72, alignment: .trailing)

            Text(transitionText)
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(palette.sec)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 114, alignment: .trailing)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Closed sessions less than an hour from opening surface it: "Opens soon" in orange.
    private var isOpeningSoon: Bool {
        guard resolved.status == .closed, let next = resolved.nextActiveStart else { return false }
        return next.timeIntervalSince(now) < 3_600
    }

    private var statusText: String {
        isOpeningSoon ? "Opens soon" : resolved.status.label
    }

    private var statusColor: Color {
        isOpeningSoon ? palette.orange : palette.statusColor(resolved.status)
    }

    private var transitionText: String {
        guard let transition = resolved.transition else { return "" }
        return MarketDateFormatting.rowTransition(
            transition,
            relativeTo: now,
            timeZone: displayTimeZone
        )
    }

    private var accessibilityLabel: String {
        var label = "\(resolved.session.name), \(statusText.lowercased())"
        if !transitionText.isEmpty {
            label += ", " + transitionText.lowercased().replacingOccurrences(of: "≈", with: "approximately ")
        }
        return label
    }
}
