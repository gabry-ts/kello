import Foundation

public enum AgendaFormat {
    /// A duration in its two largest units, in the locale's narrowest words: "27m",
    /// "1h 5m", "2d 3h" in English, "2 g 3 h" in Italian. Whole minutes, rounded down.
    public static func compactDuration(_ seconds: TimeInterval, locale: Locale = .current) -> String {
        let minutes = max(0, Int(seconds) / 60)
        return Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 2).locale(locale))
    }

    /// "11:00 – 11:30 AM (GMT+2)", or nil for an all-day event on a single day, which the
    /// app calls "All day". Events spanning several days show their dates as well. Compact
    /// rows leave the time zone out.
    public static func timeRange(start: Date, end: Date, isAllDay: Bool, showsTimeZone: Bool = true,
                                 calendar: Calendar = .current, locale: Locale = .current) -> String? {
        if isAllDay {
            let lastDay = calendar.date(byAdding: .day, value: -1, to: end) ?? end
            guard end > start, !calendar.isDate(start, inSameDayAs: lastDay) else { return nil }
            let style = Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
            return (start..<max(start, lastDay)).formatted(style)
        }
        var style = Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).hour().minute()
        if !calendar.isDate(start, inSameDayAs: end.addingTimeInterval(-1)) {
            style = style.day().month(.abbreviated)
        }
        let range = (start..<max(start, end)).formatted(style)
        guard showsTimeZone else { return range }
        let zone = start.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).timeZone(.localizedGMT(.short)))
        return "\(range) (\(zone))"
    }

    /// Up to `limit` distinct calendar colors per day, keyed by start of day, in the order
    /// their first event starts.
    public static func dotColors(days: [Date], events: [CalendarEvent], limit: Int = 4, calendar: Calendar = .current) -> [Date: [ItemColor]] {
        let sorted = events.sorted { $0.start < $1.start }
        var result: [Date: [ItemColor]] = [:]
        for day in days {
            let start = calendar.startOfDay(for: day)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
            let interval = DateInterval(start: start, end: end)
            var colors: [ItemColor] = []
            for event in sorted where event.overlaps(interval) && !colors.contains(event.color) {
                colors.append(event.color)
                if colors.count == limit { break }
            }
            if !colors.isEmpty { result[start] = colors }
        }
        return result
    }
}

/// The counts shown under the grid.
public struct AgendaStatus: Hashable, Sendable {
    public let overdueCount: Int
    public let todayCount: Int
    /// One per calendar with events today, in order of each calendar's first event.
    public let todayColors: [ItemColor]

    public init(events: [CalendarEvent], reminders: [ReminderItem], now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let todays = events
            .filter { $0.overlaps(DateInterval(start: today, end: tomorrow)) && !$0.isCancelled }
            .sorted { $0.start < $1.start }
        overdueCount = reminders.filter { $0.isOverdue(now: now, calendar: calendar) }.count
        todayCount = todays.count
        var colors: [ItemColor] = []
        for event in todays where !colors.contains(event.color) { colors.append(event.color) }
        todayColors = colors
    }
}
