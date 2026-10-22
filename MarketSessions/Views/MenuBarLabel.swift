import AppKit
import SwiftUI

/// A fixed glyph; the popover and tooltip carry the market state and the next change.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone

    /// Four outlined bars off one straight middle line, two hanging below and two rising
    /// above (owner decision 2026-10-21). Drawn per backing scale as a template image so
    /// the system tints it; `handoff/app-icon/` holds the same shape for the app icon.
    private static let glyph: NSImage = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            let stroke: CGFloat = 1.2
            let inset = stroke / 2
            let barWidth = (16 - stroke) / 4
            let path = NSBezierPath()
            path.move(to: NSPoint(x: inset, y: 8))
            path.line(to: NSPoint(x: 16 - inset, y: 8))
            for (index, end) in [14.2, 11, 5, 1.8].enumerated() {
                let left = inset + CGFloat(index) * barWidth
                path.move(to: NSPoint(x: left, y: 8))
                path.line(to: NSPoint(x: left, y: end))
                path.line(to: NSPoint(x: left + barWidth, y: end))
                path.line(to: NSPoint(x: left + barWidth, y: 8))
            }
            path.lineWidth = stroke
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()

    var body: some View {
        Image(nsImage: Self.glyph)
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
