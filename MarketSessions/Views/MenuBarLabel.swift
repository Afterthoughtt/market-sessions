import AppKit
import SwiftUI

/// The next-to-change session's code in a pill; in the final hour before that
/// change, a countdown beside it (`[LDN] 45m`). Never a clock time, which read as a
/// second clock next to the system's. A filled pill counts to a close, an outlined
/// one to an open. Only the pill is a template image (SwiftUI shapes do not draw in
/// a MenuBarExtra label); the countdown is native text so the system sets the
/// glyph-to-title gap.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone
    let showsCountdown: Bool

    /// The countdown appears once the change is at most 59 minutes away, so it never reads "1h".
    nonisolated static let countdownWindow: TimeInterval = 59 * 60

    var body: some View {
        Group {
            if let resolved {
                Image(nsImage: Self.render(code: resolved.session.code, filled: Self.isFilled(resolved)))
                if showsCountdown, let countdown = Self.countdown(for: resolved, now: now) {
                    Text(countdown)
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

    /// Filled while counting to a close (Open); outlined while counting to an open,
    /// which includes After Hours (it counts to the next session's open).
    nonisolated static func isFilled(_ resolved: ResolvedSession) -> Bool {
        resolved.transition?.verb == .closes
    }

    /// `45m` … `1m` inside the countdown window; nil further out or with no next transition.
    nonisolated static func countdown(for resolved: ResolvedSession, now: Date) -> String? {
        guard let date = resolved.transition?.date, date > now,
              date.timeIntervalSince(now) <= countdownWindow else { return nil }
        return MarketDurationFormatting.compact(minutes: FocusSessionResolver.remainingMinutes(until: date, from: now))
    }

    /// Twelve possible pills (six codes, filled or not); render each once.
    @MainActor private static var pillCache: [String: NSImage] = [:]

    @MainActor
    private static func render(code: String, filled: Bool) -> NSImage {
        let scale = max(NSScreen.screens.map(\.backingScaleFactor).max() ?? 2, 2)
        let key = "\(code)-\(filled)-\(scale)"
        if let cached = pillCache[key] { return cached }
        let renderer = ImageRenderer(content: MenuBarPill(code: code, filled: filled))
        renderer.scale = scale
        guard let image = renderer.nsImage else { return NSImage() }
        image.isTemplate = true
        pillCache[key] = image
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
/// filled pill knocks its code out to transparent. 15pt tall in a 16pt glyph box,
/// which sits level with the menu bar's battery-with-percentage badge (checked by
/// eye on screen, not measured); corners use the battery body's ratio of about
/// 0.3 × height, measured from SF Symbols `battery.100percent` at the kit's
/// menu-bar configuration (13pt Semibold). The outline matches that
/// configuration's 1.3pt symbol stroke.
private struct MenuBarPill: View {
    let code: String
    let filled: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4.5, style: .continuous)
        let label = Text(code)
            .font(.system(size: 11, weight: .bold))
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
                    .overlay(shape.inset(by: 0.65).stroke(.black, lineWidth: 1.3))
            }
        }
        .frame(height: 16)
        // The system's image-to-title gap leaves ~3.5pt of ink gap; Apple's Weather
        // item (glyph + "57°F") shows ~5pt, measured from an owner screenshot.
        .padding(.trailing, 1.5)
    }
}
