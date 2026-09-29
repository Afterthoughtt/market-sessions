import Foundation

/// Countdown and progress arithmetic shared by the popover rows, the menu bar and
/// the UTC daily-close readout.
enum FocusSessionResolver {
    static func clampedProgress(now: Date, start: Date?, end: Date?) -> Double {
        guard let start, let end else { return 0 }
        let duration = end.timeIntervalSince(start)
        guard duration > 0, duration.isFinite else { return 0 }
        let elapsed = now.timeIntervalSince(start)
        guard elapsed.isFinite else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    static func remainingMinutes(until date: Date, from now: Date) -> Int {
        max(0, Int(ceil(date.timeIntervalSince(now) / 60)))
    }
}
