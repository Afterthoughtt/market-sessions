import AppKit
import SwiftUI

/// A fixed glyph; the popover and tooltip carry the market state and the next change.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone

    /// Three solid candles rising left to right, the app icon's motif (owner pick "Blue
    /// Glass", 2026-10-29). Drawn per backing scale as a template image so the system
    /// tints it; `MarketSessions/Resources/AppIcon.icon` holds the full-size icon.
    private static let glyph: NSImage = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            let bodyWidth: CGFloat = 4.2
            NSColor.black.set()
            // (centre x, wick top, body top, body bottom, wick bottom), y from the top.
            for (x, wickTop, top, bottom, wickBottom) in [
                (2.5, 5.4, 7.0, 13.4, 15.0),
                (8.0, 3.2, 4.8, 11.2, 12.8),
                (13.5, 1.0, 2.6, 9.0, 10.6),
            ] as [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] {
                let wick = NSBezierPath()
                wick.move(to: NSPoint(x: x, y: wickTop))
                wick.line(to: NSPoint(x: x, y: wickBottom))
                wick.lineWidth = 1.5
                wick.lineCapStyle = .round
                wick.stroke()
                let body = NSRect(x: x - bodyWidth / 2, y: top, width: bodyWidth, height: bottom - top)
                NSBezierPath(roundedRect: body, xRadius: bodyWidth * 0.3, yRadius: bodyWidth * 0.3).fill()
            }
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
