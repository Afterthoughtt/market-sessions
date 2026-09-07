import SwiftUI

/// A status dot, the next-to-change session's code, and a countdown to that
/// change. The dot carries the direction the way Apple's own extras do, by
/// symbol variant: filled while the countdown runs to a close, hollow while it
/// runs to an open. Everything is native text at the kit's 13pt Semibold.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone

    var body: some View {
        Group {
            if let resolved {
                if let symbol = Self.symbol(for: resolved) {
                    Image(systemName: symbol)
                }
                Text(Self.title(for: resolved, now: now))
                    .monospacedDigit()
            } else {
                // Keep Settings reachable even when the user hides every market.
                Image(systemName: "clock")
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .accessibilityLabel(tooltip)
        .help(tooltip)
    }

    /// `circle.fill` counting down to a close, `circle` to an open; nil without a transition.
    nonisolated static func symbol(for resolved: ResolvedSession) -> String? {
        switch resolved.transition?.verb {
        case .closes: "circle.fill"
        case .opens: "circle"
        case nil: nil
        }
    }

    /// `LDN 2h 14m`; just the code when the session has no next transition.
    nonisolated static func title(for resolved: ResolvedSession, now: Date) -> String {
        guard let transition = resolved.transition else { return resolved.session.code }
        let minutes = FocusSessionResolver.remainingMinutes(until: transition.date, from: now)
        return "\(resolved.session.code) \(MarketDurationFormatting.compact(minutes: minutes))"
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
