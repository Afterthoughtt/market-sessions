import AppKit
import SwiftUI

/// One monochrome ring: drains to the next close, or fills toward the next open.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone

    var body: some View {
        Image(nsImage: Self.render(resolved: resolved, now: now))
            .accessibilityLabel(tooltip)
            .help(tooltip)
    }

    @MainActor
    private static func render(resolved: ResolvedSession?, now: Date) -> NSImage {
        let renderer = ImageRenderer(content: MenuBarPill(resolved: resolved, now: now))
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
private struct MenuBarPill: View {
    let resolved: ResolvedSession?
    let now: Date

    var body: some View {
        HStack(spacing: 5) {
            if let resolved {
                ProgressRing(
                    fraction: progressFraction(for: resolved),
                    size: 14,
                    lineWidth: 3.5,
                    track: .black.opacity(0.22),
                    arc: .black
                )
                Text(resolved.session.code)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black)
            } else {
                // Keep Settings reachable even when the user hides every market.
                Image(systemName: "clock")
                    .font(.system(size: 14))
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 18)
        .fixedSize()
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
