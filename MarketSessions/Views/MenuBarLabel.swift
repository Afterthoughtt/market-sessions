import AppKit
import SwiftUI

/// The next-to-change session's code in a pill, then the clock time of that
/// change (`[LDN] 8:30 AM`, `[TYO] Sun 5:00 PM`). A filled pill counts to a
/// close, an outlined one to an open. Only the pill is a template image
/// (SwiftUI shapes do not draw in a MenuBarExtra label); the time is native
/// text so the system sets its menu bar weight and the glyph-to-title gap.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone
    let showsTime: Bool

    var body: some View {
        Group {
            if let resolved {
                Image(nsImage: Self.render(code: resolved.session.code, filled: Self.isFilled(resolved)))
                if showsTime, let time = Self.time(for: resolved, now: now, timeZone: displayTimeZone) {
                    Text(time)
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
            } else {
                // Keep Settings reachable even when the user hides every market.
                Image(systemName: "clock")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tooltip)
        .help(tooltip)
    }

    /// Filled while counting to a close (Open, After Hours); outlined while counting to an open.
    nonisolated static func isFilled(_ resolved: ResolvedSession) -> Bool {
        resolved.transition?.verb == .closes
    }

    /// `8:30 AM` today, `Sun 5:00 PM` on another day; nil when there is no next transition.
    nonisolated static func time(
        for resolved: ResolvedSession,
        now: Date,
        timeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        guard let transition = resolved.transition else { return nil }
        return MarketDateFormatting.transitionTime(
            transition.date, relativeTo: now, timeZone: timeZone, locale: locale
        )
    }

    @MainActor
    private static func render(code: String, filled: Bool) -> NSImage {
        let renderer = ImageRenderer(content: MenuBarPill(code: code, filled: filled))
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

/// Drawn in black so the template image follows the active menu-bar tint; the
/// filled pill knocks its code out to transparent. Sized to the 16pt glyph box
/// of an SF Symbol at the kit's menu-bar configuration (13pt Semibold).
private struct MenuBarPill: View {
    let code: String
    let filled: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        let label = Text(code)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.3)
            .padding(.horizontal, 3.5)
            .frame(height: 15)

        Group {
            if filled {
                label
                    .foregroundStyle(.black)
                    .blendMode(.destinationOut)
                    .background(shape.fill(.black))
                    .compositingGroup()
            } else {
                label
                    .foregroundStyle(.black)
                    .overlay(shape.inset(by: 0.5).stroke(.black, lineWidth: 1))
            }
        }
        .frame(height: 16)
    }
}
