import SwiftUI

/// The next-to-change session's code, the transition verb, and a countdown to
/// it (`LDN closes 1h 18m`, `TYO opens 2h 40m`) as native status-item text at
/// the kit's 13pt Semibold with tabular figures.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone

    var body: some View {
        Group {
            if let resolved {
                Text(Self.title(for: resolved, now: now))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            } else {
                // Keep Settings reachable even when the user hides every market.
                Image(systemName: "clock")
            }
        }
        .accessibilityLabel(tooltip)
        .help(tooltip)
    }

    /// `LDN closes 1h 18m`; just the code when the session has no next transition.
    nonisolated static func title(for resolved: ResolvedSession, now: Date) -> String {
        guard let transition = resolved.transition else { return resolved.session.code }
        let minutes = FocusSessionResolver.remainingMinutes(until: transition.date, from: now)
        let verb = transition.verb.rawValue.lowercased()
        return "\(resolved.session.code) \(verb) \(MarketDurationFormatting.compact(minutes: minutes))"
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
