import Foundation

/// Which day starts a week in the grid.
public enum FirstWeekday: String, Codable, CaseIterable, Sendable {
    /// Whatever the current locale/region says.
    case system
    case monday
    case sunday
}

/// One cell in the grid: a date, whether it belongs to the displayed month, and its
/// day-of-month number for display.
public struct MonthDay: Hashable, Sendable {
    public let date: Date
    public let day: Int
    public let isInCurrentMonth: Bool

    public init(date: Date, day: Int, isInCurrentMonth: Bool) {
        self.date = date
        self.day = day
        self.isInCurrentMonth = isInCurrentMonth
    }
}

/// One row of the grid: 7 days and the ISO 8601 week number of its first day.
public struct MonthWeek: Hashable, Sendable {
    public let days: [MonthDay]
    public let weekNumber: Int

    public init(days: [MonthDay], weekNumber: Int) {
        self.days = days
        self.weekNumber = weekNumber
    }
}

/// A 6-row, 7-column grid for one month, padded with the trailing days of the previous
/// month and the leading days of the next so every row is full.
public struct MonthGrid: Hashable, Sendable {
    public let weeks: [MonthWeek]

    public init(weeks: [MonthWeek]) {
        self.weeks = weeks
    }

    public static func rows(year: Int, month: Int, firstWeekday: FirstWeekday, timeZone: TimeZone = .current) -> MonthGrid {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = resolvedFirstWeekday(firstWeekday, calendar: calendar)

        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.timeZone = timeZone

        guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return MonthGrid(weeks: [])
        }

        // The weekday component is always Sunday-based (1...7) regardless of firstWeekday;
        // this offset finds how many days to step back to the grid's first cell.
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: firstOfMonth) else {
            return MonthGrid(weeks: [])
        }

        var weeks: [MonthWeek] = []
        var cursor = gridStart
        for _ in 0..<6 {
            var days: [MonthDay] = []
            for _ in 0..<7 {
                let dayNumber = calendar.component(.day, from: cursor)
                let cellMonth = calendar.component(.month, from: cursor)
                let cellYear = calendar.component(.year, from: cursor)
                days.append(MonthDay(date: cursor, day: dayNumber, isInCurrentMonth: cellMonth == month && cellYear == year))
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
            let weekNumber = isoCalendar.component(.weekOfYear, from: days[0].date)
            weeks.append(MonthWeek(days: days, weekNumber: weekNumber))
        }
        return MonthGrid(weeks: weeks)
    }

    private static func resolvedFirstWeekday(_ setting: FirstWeekday, calendar: Calendar) -> Int {
        switch setting {
        case .system: calendar.firstWeekday
        case .monday: 2
        case .sunday: 1
        }
    }
}
