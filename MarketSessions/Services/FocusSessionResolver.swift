import Foundation

/// Countdown arithmetic shared by the popover rows, the menu bar and the UTC
/// daily-close readout.
enum FocusSessionResolver {
    static func remainingMinutes(until date: Date, from now: Date) -> Int {
        max(0, Int(ceil(date.timeIntervalSince(now) / 60)))
    }
}
