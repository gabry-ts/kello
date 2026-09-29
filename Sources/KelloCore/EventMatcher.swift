import Foundation

/// Matches events against a search query: every word of it has to appear in the title, the
/// location or the notes, ignoring case and accents.
public struct EventMatcher: Sendable {
    public let terms: [String]

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]

    public init(query: String) {
        terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    public var isEmpty: Bool { terms.isEmpty }

    public func matches(_ event: CalendarEvent) -> Bool {
        guard !terms.isEmpty else { return false }
        let fields = [event.title, event.location, event.notes].compactMap { $0 }
        return terms.allSatisfy { term in
            fields.contains { $0.range(of: term, options: Self.options) != nil }
        }
    }

    /// The matching events grouped by the day they start: upcoming days first, soonest
    /// first, then past days, most recent first. At most `limit` events are kept, upcoming
    /// ones before past ones.
    public func sections(
        in events: [CalendarEvent],
        now: Date,
        limit: Int = 200,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [AgendaSection] {
        let today = calendar.startOfDay(for: now)
        var seen: Set<String> = []
        let found = events
            .filter { self.matches($0) && seen.insert($0.id).inserted }
            .sorted(by: Self.startOrder)
        let upcoming = found.filter { calendar.startOfDay(for: $0.start) >= today }
        let past = found.filter { calendar.startOfDay(for: $0.start) < today }
        let kept = Array(upcoming.prefix(limit)) + Array(past.suffix(max(0, limit - upcoming.count)))

        var days: [Date: [CalendarEvent]] = [:]
        for event in kept {
            days[calendar.startOfDay(for: event.start), default: []].append(event)
        }
        let order = days.keys.filter { $0 >= today }.sorted() + days.keys.filter { $0 < today }.sorted(by: >)
        return order.map { day in
            AgendaSection(title: Self.title(for: day, now: now, calendar: calendar, locale: locale),
                          entries: (days[day] ?? []).map(AgendaEntry.event))
        }
    }

    private static func startOrder(_ a: CalendarEvent, _ b: CalendarEvent) -> Bool {
        if a.start != b.start { return a.start < b.start }
        return a.title.localizedStandardCompare(b.title) == .orderedAscending
    }

    /// "Today", "Yesterday" and "Tomorrow", otherwise a short date, with the year when it
    /// isn't this one: "Thu, Oct 8", "Mon, Jan 4, 2027".
    public static func title(for day: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: day)).day ?? 0
        if (-1...1).contains(offset) {
            return Agenda.sectionTitle(for: day, now: now, calendar: calendar, locale: locale)
        }
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.abbreviated).day().month(.abbreviated)
        if calendar.component(.year, from: day) != calendar.component(.year, from: now) {
            style = style.year()
        }
        return day.formatted(style)
    }
}
