import AppKit
import SwiftUI

/// Status-item label: ticker code + progress ring, per the Turn 7 handoff with the
/// "2b" variant — both rings fill; how full the ring is, is how close the moment is.
/// The left ring is the open market filling toward its close; the right ring is the
/// next session filling toward its open, further set apart by a dotted track and
/// reduced opacity. When nothing trades the pill degrades to the next ring and code,
/// dimmed to 0.62.
///
/// The pill is rendered to a template NSImage so shapes and opacities survive the
/// menu bar (SwiftUI shape views do not draw reliably in a MenuBarExtra label).
struct MenuBarLabel: View {
    let focus: FocusSnapshot

    var body: some View {
        Image(nsImage: Self.render(focus))
            .accessibilityLabel(accessibilityLabel)
    }

    @MainActor
    private static func render(_ focus: FocusSnapshot) -> NSImage {
        let renderer = ImageRenderer(content: MenuBarPill(focus: focus))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return NSImage() }
        image.isTemplate = true
        return image
    }

    private var accessibilityLabel: String {
        if let hero = focus.hero {
            var label = "\(hero.name), \(hero.status.label.lowercased()), "
            label += "\(hero.transition.verb.rawValue.lowercased()) in "
            label += MarketDurationFormatting.spoken(minutes: hero.remainingMinutes) + "."
            if let next = focus.nextToOpen {
                label += " \(next.name) opens in "
                label += MarketDurationFormatting.spoken(minutes: next.remainingMinutes) + "."
            }
            return label
        }
        if let next = focus.nextToOpen {
            return "No markets open. \(next.name) opens in "
                + MarketDurationFormatting.spoken(minutes: next.remainingMinutes) + "."
        }
        return "Market Sessions, schedule unavailable"
    }
}

/// Drawn all in black; the template rendering keeps only the alpha channel, so the
/// menu bar tints it correctly in light, dark, and inactive states.
private struct MenuBarPill: View {
    let focus: FocusSnapshot

    var body: some View {
        HStack(spacing: 5) {
            if let hero = focus.hero {
                ring(fraction: hero.elapsedFraction, secondary: false)
                code(hero.code, opacity: 1)
                if let next = focus.nextToOpen {
                    Text("›")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.55)
                        .padding(.horizontal, 1)
                    ring(fraction: next.fillFraction, secondary: true)
                        .opacity(0.8)
                    code(next.code, opacity: 0.8)
                }
            } else if let next = focus.nextToOpen {
                ring(fraction: next.fillFraction, secondary: true)
                code(next.code, opacity: 1)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 7)
        .background(RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.32)))
        .opacity(focus.hero == nil ? 0.62 : 1)
        .fixedSize()
    }

    private func ring(fraction: Double, secondary: Bool) -> some View {
        ProgressRing(
            fraction: fraction,
            size: 14,
            lineWidth: 2,
            track: .black.opacity(0.34),
            arc: .black.opacity(secondary ? 0.95 : 1),
            dashedTrack: secondary
        )
    }

    private func code(_ text: String, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.black)
            .opacity(opacity)
    }
}
