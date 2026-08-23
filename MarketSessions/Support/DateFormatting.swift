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

    static func transition(
        _ date: Date,
        relativeTo now: Date,
        calendar baseCalendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        var calendar = baseCalendar
        calendar.timeZone = timeZone

        let prefix: String
        if calendar.isDate(date, inSameDayAs: now) {
            prefix = "Today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(date, inSameDayAs: tomorrow) {
            prefix = "Tomorrow"
        } else {
            let weekday = DateFormatter()
            weekday.locale = locale
            weekday.timeZone = timeZone
            weekday.dateFormat = "EEE"
            prefix = weekday.string(from: date)
        }

        return "\(prefix) \(time(date, timeZone: timeZone, locale: locale))"
    }

    static func interval(
        start: Date,
        end: Date,
        timeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        "\(time(start, timeZone: timeZone, locale: locale))–\(time(end, timeZone: timeZone, locale: locale))"
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
        if remainingMinutes > 0 || components.isEmpty {
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
        if remainingMinutes > 0 || components.isEmpty {
            components.append(
                "\(remainingMinutes) \(remainingMinutes == 1 ? "minute" : "minutes")"
            )
        }

        return components.joined(separator: ", ")
    }
}
