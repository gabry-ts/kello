import Foundation

/// A calendar or reminder list color, in sRGB.
public struct ItemColor: Hashable, Sendable, Codable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// A calendar or a reminder list, as shown in pickers and the visibility settings.
public struct CalendarInfo: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    /// The account it belongs to, e.g. "iCloud", "Google", "Exchange" or "On My Mac".
    public let sourceTitle: String
    public let color: ItemColor
    public let isWritable: Bool

    public init(id: String, title: String, sourceTitle: String, color: ItemColor, isWritable: Bool) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.color = color
        self.isWritable = isWritable
    }

    /// Sorted by account, then title, the way Calendar.app lists them.
    public static func sortedForDisplay(_ calendars: [CalendarInfo]) -> [CalendarInfo] {
        calendars.sorted {
            let source = $0.sourceTitle.localizedStandardCompare($1.sourceTitle)
            if source != .orderedSame { return source == .orderedAscending }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}

/// The calendars of one account, for lists grouped by source.
public struct CalendarGroup: Hashable, Sendable, Identifiable {
    public var id: String { sourceTitle }
    public let sourceTitle: String
    public let calendars: [CalendarInfo]

    public init(sourceTitle: String, calendars: [CalendarInfo]) {
        self.sourceTitle = sourceTitle
        self.calendars = calendars
    }

    /// Groups in display order, one per account.
    public static func grouped(_ calendars: [CalendarInfo]) -> [CalendarGroup] {
        var groups: [CalendarGroup] = []
        for calendar in CalendarInfo.sortedForDisplay(calendars) {
            if let last = groups.last, last.sourceTitle == calendar.sourceTitle {
                groups[groups.count - 1] = CalendarGroup(sourceTitle: last.sourceTitle, calendars: last.calendars + [calendar])
            } else {
                groups.append(CalendarGroup(sourceTitle: calendar.sourceTitle, calendars: [calendar]))
            }
        }
        return groups
    }
}

/// One occurrence of a calendar event, free of EventKit types.
public struct CalendarEvent: Hashable, Sendable, Identifiable {
    /// Unique per occurrence, since every occurrence of a recurring event shares
    /// `eventIdentifier`.
    public var id: String { "\(eventIdentifier)|\(start.timeIntervalSinceReferenceDate)" }
    public let eventIdentifier: String
    public let calendarID: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let location: String?
    public let notes: String?
    public let url: URL?
    public let isRecurring: Bool
    public let isDeclined: Bool
    public let isCancelled: Bool
    public let color: ItemColor
    /// A video call link found in the URL, location or notes.
    public let meetingURL: URL?

    public init(
        eventIdentifier: String,
        calendarID: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        isRecurring: Bool = false,
        isDeclined: Bool = false,
        isCancelled: Bool = false,
        color: ItemColor,
        meetingURL: URL? = nil
    ) {
        self.eventIdentifier = eventIdentifier
        self.calendarID = calendarID
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.url = url
        self.isRecurring = isRecurring
        self.isDeclined = isDeclined
        self.isCancelled = isCancelled
        self.color = color
        self.meetingURL = meetingURL
    }

    /// Over by `now`; drawn dimmed.
    public func isPast(now: Date) -> Bool {
        end <= now
    }

    public func isOngoing(now: Date) -> Bool {
        start <= now && now < end
    }

    /// The location, or else the first non-empty line of the notes.
    public var subtitle: String? {
        if let location = location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
            return location
        }
        return notes?
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }

    /// Whether the event touches `day`. All-day and timed events both end exclusively, so an
    /// event ending at midnight doesn't spill into the next day.
    public func overlaps(_ interval: DateInterval) -> Bool {
        start < interval.end && (end > interval.start || (end == start && start >= interval.start))
    }
}

/// An incomplete reminder, free of EventKit types.
public struct ReminderItem: Hashable, Sendable, Identifiable {
    public let id: String
    public let listID: String
    public let title: String
    /// Start of the due day when `hasDueTime` is false.
    public let due: Date?
    public let hasDueTime: Bool
    public let notes: String?
    /// EventKit's scale: 0 none, 1 high ... 9 low.
    public let priority: Int
    public let color: ItemColor

    public init(id: String, listID: String, title: String, due: Date?, hasDueTime: Bool, notes: String? = nil, priority: Int = 0, color: ItemColor) {
        self.id = id
        self.listID = listID
        self.title = title
        self.due = due
        self.hasDueTime = hasDueTime
        self.notes = notes
        self.priority = priority
        self.color = color
    }

    /// Past its due time, or for a date-only reminder, due on an earlier day.
    public func isOverdue(now: Date, calendar: Calendar = .current) -> Bool {
        guard let due else { return false }
        return hasDueTime ? due < now : due < calendar.startOfDay(for: now)
    }
}
