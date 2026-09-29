import Foundation

public enum AgendaFormat {
    /// How long ago a reminder was due, in its two largest units: "25d 23h ago",
    /// "3h 12m ago", "12m ago", or "now" under a minute.
    public static func overdueAge(since due: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(due)
        guard seconds >= 60 else { return String(localized: "now") }
        return String(localized: "\(compactDuration(seconds)) ago")
    }

    /// A duration in its two largest units: "27m", "1h 5m", "2d 3h".
    public static func compactDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds) / 60)
        let days = minutes / 1440, hours = (minutes % 1440) / 60, mins = minutes % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h" }
        return "\(mins)m"
    }

    /// "11:00 – 11:30 AM (GMT+2)", or "All day". Events spanning several days show their
    /// dates as well. Compact rows leave the time zone out.
    public static func timeRange(start: Date, end: Date, isAllDay: Bool, showsTimeZone: Bool = true,
                                 calendar: Calendar = .current, locale: Locale = .current) -> String {
        if isAllDay {
            let lastDay = calendar.date(byAdding: .day, value: -1, to: end) ?? end
            guard end > start, !calendar.isDate(start, inSameDayAs: lastDay) else { return String(localized: "All day") }
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

/// Finds a video call link among an event's URL, location and notes.
public enum MeetingLink {
    private static let hosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com",
        "facetime.apple.com", "whereby.com", "meet.jit.si", "chime.aws", "gotomeeting.com",
    ]

    public static func find(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                guard let url = match.url, let host = url.host()?.lowercased() else { continue }
                if hosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) { return url }
            }
        }
        return nil
    }
}
