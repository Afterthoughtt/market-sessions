import AppKit
import SwiftUI

/// One monochrome ring: drains to the next close, or fills toward the next open.
/// Only the ring is rendered to a template image (SwiftUI shapes do not draw in
/// a MenuBarExtra label); the code is native text so the system sets its menu
/// bar weight and the glyph-to-title gap.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone

    var body: some View {
        Group {
            if let resolved {
                Image(nsImage: Self.render(resolved: resolved, now: now))
                Text(resolved.session.code)
            } else {
                // Keep Settings reachable even when the user hides every market.
                Image(systemName: "clock")
            }
        }
        .accessibilityLabel(tooltip)
        .help(tooltip)
    }

    @MainActor
    private static func render(resolved: ResolvedSession, now: Date) -> NSImage {
        let renderer = ImageRenderer(content: MenuBarRing(resolved: resolved, now: now))
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
/// Ring metrics copy the SF Symbol `circle` at the kit's menu-bar glyph
/// configuration (13pt Semibold): 16pt box, 14pt outer diameter, 1.5pt
/// stroke, measured from a rendered symbol.
private struct MenuBarRing: View {
    let resolved: ResolvedSession
    let now: Date

    var body: some View {
        ProgressRing(
            fraction: progressFraction(for: resolved),
            size: 14,
            lineWidth: 1.5,
            track: .black.opacity(0.3),
            arc: .black
        )
        .frame(width: 16, height: 16)
    }

    private func progressFraction(for resolved: ResolvedSession) -> Double {
        if resolved.status.isActive {
            return resolved.remainingTradingFraction(at: now)
        }

        return FocusSessionResolver.clampedProgress(
            now: now,
            start: resolved.previousActiveEnd,
            end: resolved.transition?.date
        )
    }
}
