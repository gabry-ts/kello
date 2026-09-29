import Foundation

/// Which calendar's events count as holidays.
public enum HolidayCalendarChoice: Codable, Hashable, Sendable {
    /// Until one is picked: a calendar that looks like a holidays calendar, if any.
    case automatic
    case none
    case calendar(String)

    /// The chosen calendar, if it still exists.
    public func resolvedID(among calendars: [CalendarInfo]) -> String? {
        switch self {
        case .automatic: Holidays.suggestedCalendarID(among: calendars)
        case .none: nil
        case .calendar(let id): calendars.contains { $0.id == id } ? id : nil
        }
    }
}

public enum Holidays {
    /// Matched in calendar titles, ignoring case and accents.
    private static let keywords = ["holiday", "festivita"]

    /// A calendar whose title mentions holidays, preferring subscribed ones like the
    /// built-in holidays calendar over ones someone made by hand.
    public static func suggestedCalendarID(among calendars: [CalendarInfo]) -> String? {
        let matching = CalendarInfo.sortedForDisplay(calendars).filter { calendar in
            let title = calendar.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            return keywords.contains { title.contains($0) }
        }
        return (matching.first(where: \.isSubscribed) ?? matching.first)?.id
    }

    /// The titles of the holidays touching `interval`, in start order, without repeats.
    public static func names(in interval: DateInterval, holidays: [CalendarEvent]) -> [String] {
        var names: [String] = []
        for holiday in holidays.sorted(by: { $0.start < $1.start }) where holiday.overlaps(interval) && !names.contains(holiday.title) {
            names.append(holiday.title)
        }
        return names
    }

    /// Which of `days` (as start of day) have a holiday.
    public static func days(_ days: [Date], holidays: [CalendarEvent], calendar: Calendar = .current) -> Set<Date> {
        var result: Set<Date> = []
        for day in days {
            let start = calendar.startOfDay(for: day)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
            if holidays.contains(where: { $0.overlaps(DateInterval(start: start, end: end)) }) { result.insert(start) }
        }
        return result
    }
}
