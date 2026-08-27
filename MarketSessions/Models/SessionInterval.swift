import Foundation

enum Weekday: Int, CaseIterable, Hashable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
}

struct LocalTime: Hashable, Sendable {
    let hour: Int
    let minute: Int

    init(_ hour: Int, _ minute: Int = 0) {
        precondition((0..<24).contains(hour))
        precondition((0..<60).contains(minute))
        self.hour = hour
        self.minute = minute
    }
}

enum SessionIntervalKind: Hashable, Sendable {
    case trading
    case auction
    case recess
    case maintenance

    /// Trading and auctions count as "open" — orders can match.
    var countsAsActive: Bool {
        self == .trading || self == .auction
    }
}

struct SessionInterval: Hashable, Sendable {
    let weekdays: Set<Weekday>
    let start: LocalTime
    let end: LocalTime
    let endDayOffset: Int
    let kind: SessionIntervalKind

    init(
        weekdays: Set<Weekday>,
        start: LocalTime,
        end: LocalTime,
        endDayOffset: Int = 0,
        kind: SessionIntervalKind = .trading
    ) {
        precondition(endDayOffset >= 0)
        self.weekdays = weekdays
        self.start = start
        self.end = end
        self.endDayOffset = endDayOffset
        self.kind = kind
    }
}
