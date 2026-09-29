import AppKit
import EventKit
import KelloCore
import Observation

/// The one EventKit store the app reads from, with the access state for events and
/// reminders. Any change in the Calendar database bumps `revision`, so views that read it
/// fetch again.
@MainActor
@Observable
final class CalendarStore {
    enum Access {
        case notDetermined
        case granted
        /// Kello can add events but not read them, which is not enough to show anything.
        case writeOnly
        case denied
    }

    private(set) var eventsAccess: Access
    private(set) var remindersAccess: Access
    private(set) var revision = 0

    @ObservationIgnored let eventStore = EKEventStore()
    @ObservationIgnored private var observer: NSObjectProtocol?
    /// False for the store used when rendering offscreen snapshots, which never touches
    /// the real Calendar database and serves the sample items below instead.
    @ObservationIgnored private let isLive: Bool
    @ObservationIgnored private var sampleEvents: [CalendarEvent] = []
    @ObservationIgnored private var sampleCalendars: [CalendarInfo] = []

    /// Fetches memoized per `revision`, since views ask for the same ranges on every redraw.
    @ObservationIgnored private var cachedRevision = -1
    @ObservationIgnored private var eventCache: [DateInterval: [CalendarEvent]] = [:]
    @ObservationIgnored private var calendarCache: [CalendarInfo]?

    init() {
        isLive = true
        eventsAccess = Self.access(for: .event)
        remindersAccess = Self.access(for: .reminder)
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.storeChanged() }
        }
    }

    init(eventsAccess: Access, remindersAccess: Access, events: [CalendarEvent] = [], calendars: [CalendarInfo] = []) {
        isLive = false
        self.eventsAccess = eventsAccess
        self.remindersAccess = remindersAccess
        sampleEvents = events
        sampleCalendars = calendars
    }

    // MARK: Reading

    /// Every event occurrence overlapping `interval`, across all calendars.
    func events(in interval: DateInterval) -> [CalendarEvent] {
        invalidateIfStale()
        guard eventsAccess == .granted else { return [] }
        if let cached = eventCache[interval] { return cached }
        let events: [CalendarEvent]
        if isLive {
            let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
            events = eventStore.events(matching: predicate).map(CalendarEvent.init)
        } else {
            events = sampleEvents.filter { $0.overlaps(interval) }
        }
        eventCache[interval] = events
        return events
    }

    /// Every event calendar, sorted by account and then title.
    var eventCalendars: [CalendarInfo] {
        invalidateIfStale()
        guard eventsAccess == .granted else { return [] }
        if let calendarCache { return calendarCache }
        let calendars = CalendarInfo.sortedForDisplay(isLive ? eventStore.calendars(for: .event).map(CalendarInfo.init) : sampleCalendars)
        calendarCache = calendars
        return calendars
    }

    /// Calendars new events can go in.
    var writableCalendars: [CalendarInfo] {
        eventCalendars.filter(\.isWritable)
    }

    /// The system's default calendar for new events, unless it's hidden or read-only.
    func defaultCalendarID(hidden: Set<String>) -> String {
        let writable = writableCalendars
        if isLive, let id = eventStore.defaultCalendarForNewEvents?.calendarIdentifier,
           !hidden.contains(id), writable.contains(where: { $0.id == id }) {
            return id
        }
        return (writable.first { !hidden.contains($0.id) } ?? writable.first)?.id ?? ""
    }

    // MARK: Writing

    enum WriteError: LocalizedError {
        case notFound
        case noCalendar

        var errorDescription: String? {
            switch self {
            case .notFound: String(localized: "The event no longer exists.")
            case .noCalendar: String(localized: "Choose a calendar for the event.")
            }
        }
    }

    /// A draft of an existing occurrence, for the editor.
    func draft(for event: CalendarEvent) -> EventDraft? {
        guard isLive else { return EventDraft(sample: event) }
        return findEvent(event.eventIdentifier, occurrenceStart: event.start).map(EventDraft.init)
    }

    /// Creates or updates the event. For recurring events `span` picks this occurrence
    /// only or it and all future ones.
    func save(_ draft: EventDraft, span: EKSpan) throws {
        guard isLive else { return }
        let event: EKEvent
        if let identifier = draft.eventIdentifier {
            guard let existing = findEvent(identifier, occurrenceStart: draft.occurrenceStart) else { throw WriteError.notFound }
            event = existing
        } else {
            event = EKEvent(eventStore: eventStore)
        }
        guard let calendar = eventStore.calendar(withIdentifier: draft.calendarID) else { throw WriteError.noCalendar }

        event.calendar = calendar
        event.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.isAllDay = draft.isAllDay
        if draft.isAllDay {
            // EventKit takes an all-day event's end as the last day it covers.
            event.startDate = Calendar.current.startOfDay(for: draft.start)
            event.endDate = Calendar.current.startOfDay(for: max(draft.start, draft.end))
        } else {
            event.startDate = draft.start
            event.endDate = max(draft.start, draft.end)
        }
        event.location = draft.location.nilIfBlank
        event.url = draft.parsedURL
        event.notes = draft.notes.nilIfBlank
        if draft.alert != .custom {
            event.alarms = draft.alert.offset.map { [EKAlarm(relativeOffset: $0)] }
        }
        if draft.repeatRule != .custom {
            event.recurrenceRules = draft.repeatRule.frequency.map { [EKRecurrenceRule(recurrenceWith: $0, interval: 1, end: nil)] }
        }
        try eventStore.save(event, span: span, commit: true)
        revision += 1
    }

    func delete(_ draft: EventDraft, span: EKSpan) throws {
        guard isLive, let identifier = draft.eventIdentifier else { return }
        guard let event = findEvent(identifier, occurrenceStart: draft.occurrenceStart) else { throw WriteError.notFound }
        try eventStore.remove(event, span: span, commit: true)
        revision += 1
    }

    /// The occurrence of a (possibly recurring) event starting at `occurrenceStart`, found
    /// by fetching that day, since `event(withIdentifier:)` returns the first occurrence.
    private func findEvent(_ identifier: String, occurrenceStart: Date?) -> EKEvent? {
        if let occurrenceStart {
            let predicate = eventStore.predicateForEvents(withStart: occurrenceStart.addingTimeInterval(-1),
                                                          end: occurrenceStart.addingTimeInterval(86400), calendars: nil)
            if let match = eventStore.events(matching: predicate).first(where: {
                $0.eventIdentifier == identifier && $0.startDate == occurrenceStart
            }) {
                return match
            }
        }
        return eventStore.event(withIdentifier: identifier)
    }

    /// Reading `revision` here also registers it with observation, so every view that
    /// fetches through the store redraws when the database changes.
    private func invalidateIfStale() {
        guard cachedRevision != revision else { return }
        cachedRevision = revision
        eventCache = [:]
        calendarCache = nil
    }

    /// The popover asks for access when events are readable but reminders were never asked
    /// about, or when events aren't readable at all.
    var needsPermissionPrompt: Bool {
        eventsAccess != .granted || remindersAccess == .notDetermined
    }

    /// Asked once on first launch, events first, so the user sees the prompts in context.
    func requestAccessIfNeeded() async {
        if eventsAccess == .notDetermined { await requestEventsAccess() }
        if remindersAccess == .notDetermined { await requestRemindersAccess() }
    }

    func requestEventsAccess() async {
        guard isLive else { return }
        _ = try? await eventStore.requestFullAccessToEvents()
        refreshAccess()
    }

    func requestRemindersAccess() async {
        guard isLive else { return }
        _ = try? await eventStore.requestFullAccessToReminders()
        refreshAccess()
    }

    /// Re-reads the access state, which can change in System Settings while Kello runs.
    func refreshAccess() {
        guard isLive else { return }
        let events = Self.access(for: .event)
        let reminders = Self.access(for: .reminder)
        guard events != eventsAccess || reminders != remindersAccess else { return }
        eventsAccess = events
        remindersAccess = reminders
        // Access changes don't post EKEventStoreChanged; the store's sources need a reset
        // before newly allowed data shows up.
        eventStore.reset()
        revision += 1
    }

    /// Opens the Calendars or Reminders page of Privacy & Security in System Settings.
    func openPrivacySettings(for type: EKEntityType) {
        let anchor = type == .event ? "Privacy_Calendars" : "Privacy_Reminders"
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func storeChanged() {
        revision += 1
    }

    private static func access(for type: EKEntityType) -> Access {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess: .granted
        case .writeOnly: .writeOnly
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
