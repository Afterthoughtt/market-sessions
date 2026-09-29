import Foundation

enum MarketDateFormatting {
    static func time(
        _ date: Date,
        timeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        dateTime(date, dateStyle: .none, timeZone: timeZone, locale: locale)
    }

    /// Date plus short time, `Mar 17, 2027 at 11:00 PM`, with the same spacing as `time`.
    static func dateTime(
        _ date: Date,
        dateStyle: DateFormatter.Style,
        timeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = dateStyle
        formatter.timeStyle = .short
        // Foundation separates "PM" with a narrow no-break space (U+202F), which reads
        // cramped at 13pt; the kit's menu bar clock uses a full space ("9:41 AM").
        return formatter.string(from: date).replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// `1:00 PM` on the same display day, `Sun 3:00 PM` otherwise.
    static func transitionTime(
        _ date: Date,
        relativeTo now: Date,
        timeZone: TimeZone,
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

        let clock = time(date, timeZone: timeZone, locale: locale)
        if let prefix {
            return "\(prefix) \(clock)"
        }
        return clock
    }

    /// Hero subtitle tail: `closes Today 1:00 PM`, `opens Sun 3:00 PM`.
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
