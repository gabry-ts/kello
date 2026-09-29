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
