import Foundation

/// One line of the agenda list.
public enum AgendaEntry: Hashable, Sendable, Identifiable {
    case reminder(ReminderItem)
    case event(CalendarEvent)
    /// The "now" marker between today's past and upcoming events, with the time left until
    /// the next one starts, if any.
    case now(untilNext: TimeInterval?)

    public var id: String {
        switch self {
        case .reminder(let reminder): "r|\(reminder.id)"
        case .event(let event): "e|\(event.id)"
        case .now: "now"
        }
    }
}

/// A run of entries under one relative header ("Yesterday", "Today", "2 weeks ago").
public struct AgendaSection: Hashable, Sendable, Identifiable {
    public var id: String { title }
    public let title: String
    public let entries: [AgendaEntry]
    /// The names of the day's holidays, shown under the header.
    public let holidays: [String]

    public init(title: String, entries: [AgendaEntry], holidays: [String] = []) {
        self.title = title
        self.entries = entries
        self.holidays = holidays
    }
}

/// Which days the list covers.
public enum AgendaMode: String, Codable, Sendable {
    /// The day selected in the grid.
    case day
    /// Today and the following days.
    case upcoming
}

public enum Agenda {
    /// How many days the upcoming list spans, today included.
    public static let upcomingDays = 7

    /// The days listed: the selected day, or a week starting today.
    public static func days(mode: AgendaMode, selectedDay: Date, now: Date, calendar: Calendar = .current) -> [Date] {
        switch mode {
        case .day:
            return [calendar.startOfDay(for: selectedDay)]
        case .upcoming:
            let today = calendar.startOfDay(for: now)
            return (0..<upcomingDays).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        }
    }

    /// Builds the list. Overdue reminders come first, in one section, but only when today
    /// is among `days`; then one section per day with reminders due that day, all-day
    /// events, and timed events in start order, under the names of the day's `holidays`.
    /// Today's section gets a "now" marker. Days with nothing on them are left out.
    public static func sections(
        days: [Date],
        events: [CalendarEvent],
        reminders: [ReminderItem],
        holidays: [CalendarEvent] = [],
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [AgendaSection] {
        let today = calendar.startOfDay(for: now)
        let days = days.map { calendar.startOfDay(for: $0) }
        var sections: [AgendaSection] = []

        // Every overdue reminder, oldest first, under one "Overdue" header; they're left out
        // of the day sections below.
        let overdue = days.contains(today)
            ? reminders.filter { $0.isOverdue(now: now, calendar: calendar) }.sorted { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
            : []
        if !overdue.isEmpty {
            sections.append(AgendaSection(title: overdueTitle, entries: overdue.map(AgendaEntry.reminder)))
        }
        let pending = reminders.filter { !$0.isOverdue(now: now, calendar: calendar) }

        for day in days {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            let interval = DateInterval(start: day, end: next)
            let dayReminders = pending
                .filter { reminder in reminder.due.map { interval.contains($0) && $0 < next } ?? false }
                .sorted { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
            let dayEvents = events.filter { $0.overlaps(interval) }.sorted(by: eventOrder)
            var entries = dayReminders.map(AgendaEntry.reminder)
            entries += dayEvents.filter(\.isAllDay).map(AgendaEntry.event)

            let timed = dayEvents.filter { !$0.isAllDay }
            if day == today, !timed.isEmpty {
                // The marker goes before the first event yet to start.
                let upcomingIndex = timed.firstIndex { $0.start > now } ?? timed.count
                entries += timed[..<upcomingIndex].map(AgendaEntry.event)
                entries.append(.now(untilNext: upcomingIndex < timed.count ? timed[upcomingIndex].start.timeIntervalSince(now) : nil))
                entries += timed[upcomingIndex...].map(AgendaEntry.event)
            } else {
                entries += timed.map(AgendaEntry.event)
            }

            let holidayNames = Holidays.names(in: interval, holidays: holidays)
            guard !entries.isEmpty || !holidayNames.isEmpty else { continue }
            let title = sectionTitle(for: day, now: now, calendar: calendar, locale: locale)
            sections.append(AgendaSection(title: title, entries: entries, holidays: holidayNames))
        }
        return sections
    }

    public static var overdueTitle: String { String(localized: "Overdue") }

    /// The next event today that hasn't started yet, for the "Next up" card. Declined and
    /// cancelled events are skipped, as are all-day ones.
    public static func nextUp(events: [CalendarEvent], now: Date, calendar: Calendar = .current) -> CalendarEvent? {
        events
            .filter { !$0.isAllDay && !$0.isDeclined && !$0.isCancelled && $0.start > now && calendar.isDate($0.start, inSameDayAs: now) }
            .min(by: eventOrder)
    }

    private static func eventOrder(_ a: CalendarEvent, _ b: CalendarEvent) -> Bool {
        if a.start != b.start { return a.start < b.start }
        if a.end != b.end { return a.end < b.end }
        return a.title.localizedStandardCompare(b.title) == .orderedAscending
    }

    /// "Today", "Yesterday", "Tomorrow", "3 days ago", "2 weeks ago", "4 months ago"; days
    /// ahead get their weekday within a week, then a short date.
    public static func sectionTitle(for day: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: day)).day ?? 0
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.unitsStyle = .full

        let text: String
        switch offset {
        case -1...1:
            formatter.dateTimeStyle = .named
            text = formatter.localizedString(from: DateComponents(day: offset))
        case -6 ... -2:
            text = formatter.localizedString(from: DateComponents(day: offset))
        case -30 ... -7:
            text = formatter.localizedString(from: DateComponents(weekOfMonth: offset / 7))
        case ..<(-30):
            let months = max(1, calendar.dateComponents([.month], from: day, to: now).month ?? 1)
            text = formatter.localizedString(from: DateComponents(month: -months))
        case 2...6:
            var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            style = style.weekday(.wide)
            text = day.formatted(style)
        default:
            var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            style = style.weekday(.abbreviated).day().month(.abbreviated)
            text = day.formatted(style)
        }
        return text.prefix(1).uppercased(with: locale) + text.dropFirst()
    }
}
