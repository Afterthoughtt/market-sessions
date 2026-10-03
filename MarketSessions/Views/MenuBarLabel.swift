import SwiftUI

/// A fixed symbol; the popover and tooltip carry the market state and the next change.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone

    var body: some View {
        Image(systemName: "chart.line.uptrend.xyaxis")
            .accessibilityLabel(tooltip)
            .help(tooltip)
    }

    private var tooltip: String {
        guard let resolved, let transition = resolved.transition else {
            return "Market Sessions — choose markets in Settings"
        }
        let time = MarketDateFormatting.transitionTime(
            transition.date,
            relativeTo: now,
            timeZone: displayTimeZone
        )
        return "\(resolved.session.name) · \(resolved.status.label) · \(transition.verb.rawValue) \(time)"
    }
}
