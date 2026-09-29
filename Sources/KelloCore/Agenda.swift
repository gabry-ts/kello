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

    public init(title: String, entries: [AgendaEntry]) {
        self.title = title
        self.entries = entries
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

    /// Builds the list. Overdue reminders come first, grouped by how long ago they were
    /// due, but only when today is among `days`; then one section per day with reminders
    /// due that day, all-day events, and timed events in start order. Today's section gets
    /// a "now" marker. Days with nothing on them are left out.
    public static func sections(
        days: [Date],
        events: [CalendarEvent],
        reminders: [ReminderItem],
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [AgendaSection] {
        let today = calendar.startOfDay(for: now)
        let days = days.map { calendar.startOfDay(for: $0) }
        var sections: [AgendaSection] = []

        if days.contains(today) {
            let overdue = reminders
                .filter { $0.isOverdue(now: now, calendar: calendar) && $0.due.map { $0 < today } == true }
                .sorted { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
            // Adjacent reminders sharing a title ("2 weeks ago") share a section.
            for reminder in overdue {
                let title = sectionTitle(for: reminder.due ?? today, now: now, calendar: calendar, locale: locale)
                if let last = sections.last, last.title == title {
                    sections[sections.count - 1] = AgendaSection(title: title, entries: last.entries + [.reminder(reminder)])
                } else {
                    sections.append(AgendaSection(title: title, entries: [.reminder(reminder)]))
                }
            }
        }

        for day in days {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            let interval = DateInterval(start: day, end: next)
            let dayReminders = reminders
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

            guard !entries.isEmpty else { continue }
            let title = sectionTitle(for: day, now: now, calendar: calendar, locale: locale)
            // A day whose title matches an overdue section joins it instead of repeating it.
            if let index = sections.firstIndex(where: { $0.title == title }) {
                sections[index] = AgendaSection(title: title, entries: sections[index].entries + entries)
            } else {
                sections.append(AgendaSection(title: title, entries: entries))
            }
        }
        return sections
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
