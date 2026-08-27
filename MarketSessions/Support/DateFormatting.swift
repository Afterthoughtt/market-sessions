import Foundation

enum MarketDateFormatting {
    static func time(
        _ date: Date,
        timeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// `1:00 PM` on the same display day, `Sun 3:00 PM` otherwise; `≈` prefixes approximate times.
    static func transitionTime(
        _ date: Date,
        relativeTo now: Date,
        timeZone: TimeZone,
        approximate: Bool = false,
        sameDayPrefix: String? = nil,
        locale: Locale = .autoupdatingCurrent,
        calendar baseCalendar: Calendar = Calendar(identifier: .gregorian)
    ) -> String {
        var calendar = baseCalendar
        calendar.timeZone = timeZone

        let prefix: String?
        if calendar.isDate(date, inSameDayAs: now) {
            prefix = sameDayPrefix
        } else {
            let weekday = DateFormatter()
            weekday.locale = locale
            weekday.timeZone = timeZone
            weekday.dateFormat = "EEE"
            prefix = weekday.string(from: date)
        }

        let clock = (approximate ? "≈" : "") + time(date, timeZone: timeZone, locale: locale)
        if let prefix {
            return "\(prefix) \(clock)"
        }
        return clock
    }

    /// Hero subtitle tail: `closes Today 1:00 PM`, `opens Sun ≈3:00 PM`.
    static func subtitleTransition(
        _ transition: SessionTransition,
        relativeTo now: Date,
        timeZone: TimeZone
    ) -> String {
        let verb = transition.verb.rawValue.lowercased()
        let time = transitionTime(
            transition.date,
            relativeTo: now,
            timeZone: timeZone,
            approximate: transition.approximate,
            sameDayPrefix: "Today"
        )
        return "\(verb) \(time)"
    }
}

enum MarketDurationFormatting {
    static func compact(minutes rawMinutes: Int) -> String {
        let minutes = max(0, rawMinutes)
        let days = minutes / (24 * 60)
        let hours = (minutes % (24 * 60)) / 60
        let remainingMinutes = minutes % 60
        var components: [String] = []

        if days > 0 {
            components.append("\(days)d")
        }
        if hours > 0 {
            components.append("\(hours)h")
        }
        if (remainingMinutes > 0 && days == 0) || components.isEmpty {
            components.append("\(remainingMinutes)m")
        }

        return components.joined(separator: " ")
    }

    static func spoken(minutes rawMinutes: Int) -> String {
        let minutes = max(0, rawMinutes)
        let days = minutes / (24 * 60)
        let hours = (minutes % (24 * 60)) / 60
        let remainingMinutes = minutes % 60
        var components: [String] = []

        if days > 0 {
            components.append("\(days) \(days == 1 ? "day" : "days")")
        }
        if hours > 0 {
            components.append("\(hours) \(hours == 1 ? "hour" : "hours")")
        }
        if (remainingMinutes > 0 && days == 0) || components.isEmpty {
            components.append(
                "\(remainingMinutes) \(remainingMinutes == 1 ? "minute" : "minutes")"
            )
        }

        return components.joined(separator: ", ")
    }
}
