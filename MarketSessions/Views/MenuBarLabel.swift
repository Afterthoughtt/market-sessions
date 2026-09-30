import AppKit
import SwiftUI

/// The next-to-change session's code in a pill; in the final hour before that
/// change, a countdown beside it (`[LDN] 45m`). Never a clock time, which read as a
/// second clock next to the system's. While counting to a close the outline traces
/// the time left; while counting to an open it is whole. Only the pill is a template
/// image (SwiftUI shapes do not draw in a MenuBarExtra label); the countdown is
/// native text so the system sets the glyph-to-title gap.
struct MenuBarLabel: View {
    let resolved: ResolvedSession?
    let now: Date
    let displayTimeZone: TimeZone
    let showsCountdown: Bool

    /// The countdown appears once the change is at most 59 minutes away, so it never reads "1h".
    nonisolated static let countdownWindow: TimeInterval = 59 * 60

    /// The trace moves in this many steps per open run, about 1.3pt of the outline
    /// each, so the clock wakes only when the trace visibly moves.
    nonisolated static let traceSteps = 60

    var body: some View {
        Group {
            if let resolved {
                Image(nsImage: Self.render(code: resolved.session.code, remaining: Self.traceRemaining(for: resolved, now: now)))
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

    /// Fraction of the open run left, rounded up to a trace step so it reaches zero only
    /// at the close. Nil while counting to an open, including After Hours (it counts to
    /// the next session's open), which keeps the whole outline.
    nonisolated static func traceRemaining(for resolved: ResolvedSession, now: Date) -> Double? {
        traceStep(for: resolved, now: now).map { Double($0) / Double(traceSteps) }
    }

    /// When the trace next moves; nil without a trace or when its next move is the close.
    nonisolated static func nextTraceStep(for resolved: ResolvedSession, now: Date) -> Date? {
        guard let step = traceStep(for: resolved, now: now), step > 1,
              let start = resolved.activeStart, let close = resolved.transition?.date else { return nil }
        return close.addingTimeInterval(-close.timeIntervalSince(start) * Double(step - 1) / Double(traceSteps))
    }

    private nonisolated static func traceStep(for resolved: ResolvedSession, now: Date) -> Int? {
        guard let transition = resolved.transition, transition.verb == .closes,
              let start = resolved.activeStart, transition.date > start else { return nil }
        let left = transition.date.timeIntervalSince(now) / transition.date.timeIntervalSince(start)
        return min(traceSteps, max(1, Int((left * Double(traceSteps)).rounded(.up))))
    }

    /// `45m` … `1m` inside the countdown window; nil further out or with no next transition.
    nonisolated static func countdown(for resolved: ResolvedSession, now: Date) -> String? {
        guard let date = resolved.transition?.date, date > now,
              date.timeIntervalSince(now) <= countdownWindow else { return nil }
        return MarketDurationFormatting.compact(minutes: FocusSessionResolver.remainingMinutes(until: date, from: now))
    }

    /// At most 61 pills per code (whole, or one of the trace steps); render each once.
    @MainActor private static var pillCache: [String: NSImage] = [:]

    @MainActor
    private static func render(code: String, remaining: Double?) -> NSImage {
        let scale = max(NSScreen.screens.map(\.backingScaleFactor).max() ?? 2, 2)
        let key = "\(code)-\(remaining.map { "\($0)" } ?? "whole")-\(scale)"
        if let cached = pillCache[key] { return cached }
        let renderer = ImageRenderer(content: MenuBarPill(code: code, remaining: remaining))
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

/// Drawn in black so the template image follows the active menu-bar tint. 15pt tall
/// in a 16pt glyph box (owner decision; the battery-with-percentage badge
/// beside it measures 12pt in an owner screenshot); corners use the battery body's
/// ratio of about 0.3 × height, measured from SF Symbols `battery.100percent` at the
/// kit's menu-bar configuration (13pt Semibold). The 1.45pt outline matches the
/// stroke SF Symbols draw at that configuration, the macOS 27 kit's status-item
/// weight (`circle` 1.46pt, `battery.0percent` 1.41pt, measured on macOS 27).
private struct MenuBarPill: View {
    let code: String
    /// Fraction of the open run left, or nil for the whole outline.
    let remaining: Double?

    var body: some View {
        let outline = RoundedRectangle(cornerRadius: 4.5, style: .continuous).inset(by: 0.725)
        let trace = StrokeStyle(lineWidth: 1.45, lineCap: .round)

        Text(code)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 3.5)
            .frame(height: 15)
            .overlay {
                if let remaining {
                    // The macOS 27 kit's unfilled progress track: black 85% at 10% opacity.
                    outline.stroke(.black.opacity(0.085), lineWidth: 1.45)
                    // SwiftUI's path starts at 3 o'clock and runs clockwise, so by symmetry
                    // 12 o'clock sits at 0.75 of its length. The trace ends there, and the
                    // elapsed gap opens clockwise from it. Round caps, like the kit's fill.
                    let from = 0.75 + (1 - remaining)
                    if from < 1 {
                        outline.trim(from: from, to: 1).stroke(.black, style: trace)
                        outline.trim(from: 0, to: 0.75).stroke(.black, style: trace)
                    } else {
                        outline.trim(from: from - 1, to: 0.75).stroke(.black, style: trace)
                    }
                } else {
                    outline.stroke(.black, lineWidth: 1.45)
                }
            }
            .frame(height: 16)
        // The system's image-to-title gap leaves ~3.5pt of ink gap; Apple's Weather
        // item (glyph + "57°F") shows ~5pt, measured from an owner screenshot.
        .padding(.trailing, 1.5)
    }
}
