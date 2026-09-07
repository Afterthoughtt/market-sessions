import AppKit
import SwiftUI

/// A status dot, the next-to-change session's code, and a countdown to that
/// change. The dot carries the direction the way Apple's own extras do, by
/// variant rather than a word: filled while the countdown runs to a close,
/// hollow while it runs to an open. Code and countdown are native text at the
/// kit's 13pt Semibold; the dot is a template image so it inverts with the bar.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone

    var body: some View {
        Group {
            if let resolved {
                if let filled = Self.dotIsFilled(for: resolved) {
                    Image(nsImage: Self.renderDot(filled: filled))
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

    /// Filled counting down to a close, hollow to an open; nil without a transition.
    nonisolated static func dotIsFilled(for resolved: ResolvedSession) -> Bool? {
        switch resolved.transition?.verb {
        case .closes: true
        case .opens: false
        case nil: nil
        }
    }

    /// `LDN 2h 14m`; just the code when the session has no next transition.
    nonisolated static func title(for resolved: ResolvedSession, now: Date) -> String {
        guard let transition = resolved.transition else { return resolved.session.code }
        let minutes = FocusSessionResolver.remainingMinutes(until: transition.date, from: now)
        return "\(resolved.session.code) \(MarketDurationFormatting.compact(minutes: minutes))"
    }

    @MainActor
    private static func renderDot(filled: Bool) -> NSImage {
        let renderer = ImageRenderer(content: MenuBarDot(filled: filled))
        renderer.scale = max(NSScreen.screens.map(\.backingScaleFactor).max() ?? 2, 2)
        guard let image = renderer.nsImage else { return NSImage() }
        image.isTemplate = true
        return image
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

/// Drawn in black so the template image follows the active menu-bar tint.
/// An 8pt dot centred in the 16pt box of the kit's 13pt Semibold menu-bar
/// glyph; the hollow variant keeps the 1.5pt stroke of that glyph weight.
private struct MenuBarDot: View {
    let filled: Bool

    var body: some View {
        Group {
            if filled {
                Circle().fill(.black)
            } else {
                Circle().strokeBorder(.black, lineWidth: 1.5)
            }
        }
        .frame(width: 8, height: 8)
        .frame(width: 16, height: 16)
    }
}
