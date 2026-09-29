import Foundation

/// When to be alerted before an event starts.
public enum AlertOption: Hashable, Sendable, CaseIterable {
    case none
    case atTime
    case minutes5
    case minutes10
    case minutes15
    case minutes30
    case hour1
    /// Alarms Kello can't express (several alarms, absolute dates, other offsets), left as
    /// they are on save.
    case custom

    public static let allCases: [AlertOption] = [.none, .atTime, .minutes5, .minutes10, .minutes15, .minutes30, .hour1]

    /// Seconds relative to the start, negative before it; nil for no alarm or `custom`.
    public var offset: TimeInterval? {
        switch self {
        case .none, .custom: nil
        case .atTime: 0
        case .minutes5: -300
        case .minutes10: -600
        case .minutes15: -900
        case .minutes30: -1800
        case .hour1: -3600
        }
    }

    /// The option matching an event's alarms, given as relative offsets (nil for an
    /// absolute-date alarm).
    public init(alarmOffsets: [TimeInterval?]) {
        guard !alarmOffsets.isEmpty else { self = .none; return }
        guard alarmOffsets.count == 1, let offset = alarmOffsets[0],
              let match = Self.allCases.first(where: { $0.offset == offset }) else { self = .custom; return }
        self = match
    }
}

/// How an event repeats.
public enum RepeatOption: Hashable, Sendable, CaseIterable {
    case never
    case daily
    case weekly
    case monthly
    case yearly
    /// A rule Kello can't express (intervals, specific weekdays, end dates), left as it is
    /// on save.
    case custom

    public static let allCases: [RepeatOption] = [.never, .daily, .weekly, .monthly, .yearly]
}

/// An event being created or edited, free of EventKit types.
public struct EventDraft: Hashable, Sendable {
    /// Nil for a new event.
    public var eventIdentifier: String?
    /// Which occurrence of a recurring event is being edited.
    public var occurrenceStart: Date?
    public var calendarID: String
    public var title: String
    public var isAllDay: Bool
    public var start: Date
    /// For all-day events, the start of the last day, as the date pickers show it.
    public var end: Date
    public var location: String
    public var url: String
    public var notes: String
    public var alert: AlertOption
    public var repeatRule: RepeatOption
    /// Whether the saved event repeats, so edits and deletes ask which occurrences to change.
    public var wasRecurring: Bool
    /// Events in calendars that don't allow changes are shown but not editable.
    public var isReadOnly: Bool

    public init(
        eventIdentifier: String? = nil,
        occurrenceStart: Date? = nil,
        calendarID: String,
        title: String = "",
        isAllDay: Bool = false,
        start: Date,
        end: Date,
        location: String = "",
        url: String = "",
        notes: String = "",
        alert: AlertOption = .none,
        repeatRule: RepeatOption = .never,
        wasRecurring: Bool = false,
        isReadOnly: Bool = false
    ) {
        self.eventIdentifier = eventIdentifier
        self.occurrenceStart = occurrenceStart
        self.calendarID = calendarID
        self.title = title
        self.isAllDay = isAllDay
        self.start = start
        self.end = end
        self.location = location
        self.url = url
        self.notes = notes
        self.alert = alert
        self.repeatRule = repeatRule
        self.wasRecurring = wasRecurring
        self.isReadOnly = isReadOnly
    }

    public var isNew: Bool { eventIdentifier == nil }

    /// A one-hour event on `day`, starting at the next full hour after `now`: today that's
    /// the upcoming hour, on other days the same hour of the day.
    public static func new(on day: Date, now: Date, calendarID: String, calendar: Calendar = .current) -> EventDraft {
        let nextHour = calendar.component(.hour, from: now) + 1
        let dayStart = calendar.startOfDay(for: day)
        let hour = calendar.isDate(day, inSameDayAs: now) ? nextHour : min(nextHour, 23)
        let start = calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? dayStart
        let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
        return EventDraft(calendarID: calendarID, start: start, end: end)
    }

    /// Saving needs a calendar and an end that isn't before the start.
    public var canSave: Bool {
        !isReadOnly && !calendarID.isEmpty && end >= start
    }

    /// The URL typed in, with "https://" assumed when no scheme was given.
    public var parsedURL: URL? {
        let text = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.contains("://") { return URL(string: text) }
        return URL(string: "https://\(text)")
    }
}
