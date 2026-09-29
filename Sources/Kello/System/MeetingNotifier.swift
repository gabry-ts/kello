import AppKit
import KelloCore
import Observation
import UserNotifications

/// Schedules a local notification shortly before each upcoming meeting, a day ahead at a
/// time. The whole set is rebuilt whenever the calendars or the settings change, and every
/// hour so the day ahead stays covered; anything of Kello's no longer wanted is removed.
@MainActor
@Observable
final class MeetingNotifier {
    enum Authorization {
        case notDetermined
        case authorized
        case denied
    }

    private(set) var authorization: Authorization

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let calendars: CalendarStore
    /// False for the notifier used when rendering offscreen snapshots, which never talks
    /// to the notification center.
    @ObservationIgnored private let isLive: Bool
    @ObservationIgnored private let delegate = Delegate()
    @ObservationIgnored private var hourlyTimer: Timer?
    @ObservationIgnored private var rescheduleTask: Task<Void, Never>?

    private static let category = "kello.meeting"
    private static let joinAction = "join"
    private static let urlKey = "meetingURL"
    private static let startKey = "start"

    init(store: SettingsStore, calendars: CalendarStore) {
        self.store = store
        self.calendars = calendars
        isLive = true
        authorization = .notDetermined
    }

    init(authorization: Authorization) {
        store = SettingsStore(settings: Settings())
        calendars = CalendarStore(eventsAccess: .denied, remindersAccess: .denied)
        isLive = false
        self.authorization = authorization
    }

    /// Takes over the notification center's delegate and starts watching for changes.
    /// `openDay` shows the popover on a meeting's day when its notification is clicked.
    func start(openDay: @escaping @MainActor (Date) -> Void) {
        guard isLive else { return }
        let center = UNUserNotificationCenter.current()
        let join = UNNotificationAction(identifier: Self.joinAction, title: String(localized: "Join"), options: [.foreground])
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.category, actions: [join], intentIdentifiers: [])])
        delegate.onResponse = { action, userInfo in
            if action == Self.joinAction, let link = userInfo[Self.urlKey], let url = URL(string: link) {
                NSWorkspace.shared.open(url)
            } else if action == UNNotificationDefaultActionIdentifier, let start = userInfo[Self.startKey].flatMap(Double.init) {
                openDay(Date(timeIntervalSinceReferenceDate: start))
            }
        }
        center.delegate = delegate
        hourlyTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reschedule() }
        }
        track()
    }

    /// Asked when the user turns notifications on, not at launch.
    func requestAuthorization() async {
        guard isLive else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        await refreshAuthorization()
        reschedule()
    }

    /// Re-reads whether Kello may notify, which can change in System Settings at any time.
    func refreshAuthorization() async {
        guard isLive else { return }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        authorization = switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .authorized
        }
    }

    /// Opens Kello's page in the Notifications settings.
    func openSystemSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Reschedules now and again on the next change to anything the alerts depend on.
    private func track() {
        withObservationTracking {
            _ = store.settings.meetingAlerts
            _ = store.settings.hiddenCalendarIDs
            _ = store.settings.holidayCalendar
            _ = calendars.revision
            _ = calendars.eventsAccess
        } onChange: { [weak self] in
            Task { @MainActor in self?.track() }
        }
        reschedule()
    }

    private func reschedule() {
        rescheduleTask?.cancel()
        rescheduleTask = Task { [weak self] in
            await self?.refreshAuthorization()
            guard !Task.isCancelled else { return }
            await self?.apply(self?.wantedAlerts() ?? [])
        }
    }

    /// The alerts the settings ask for, from visible calendars other than the holidays one.
    private func wantedAlerts() -> [MeetingAlert] {
        let settings = store.settings
        guard settings.meetingAlerts.isEnabled, authorization == .authorized, calendars.eventsAccess == .granted else { return [] }
        let now = Date.now
        let holidayCalendarID = settings.holidayCalendar.resolvedID(among: calendars.eventCalendars)
        let events = calendars.events(in: DateInterval(start: now, duration: MeetingAlerts.horizon))
            .filter { settings.isCalendarVisible($0.calendarID) && $0.calendarID != holidayCalendarID }
        return MeetingAlerts.upcoming(events: events, now: now, settings: settings.meetingAlerts)
    }

    /// Removes Kello's pending notifications that are no longer wanted, and adds or
    /// replaces the rest, so a renamed or moved meeting gets fresh content.
    private func apply(_ alerts: [MeetingAlert]) async {
        let center = UNUserNotificationCenter.current()
        let wanted = Set(alerts.map(\.id))
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(MeetingAlerts.identifierPrefix) && !wanted.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for alert in alerts {
            try? await center.add(request(for: alert))
        }
    }

    private func request(for alert: MeetingAlert) -> UNNotificationRequest {
        let event = alert.event
        let content = UNMutableNotificationContent()
        content.title = event.title
        let time = (event.start..<event.end).formatted(date: .omitted, time: .shortened)
        content.body = event.meetingService.map { "\(time) · \($0.name)" } ?? time
        content.sound = .default
        content.userInfo[Self.startKey] = String(event.start.timeIntervalSinceReferenceDate)
        if let url = event.meetingURL {
            content.categoryIdentifier = Self.category
            content.userInfo[Self.urlKey] = url.absoluteString
        }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alert.fireDate)
        return UNNotificationRequest(identifier: alert.id, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
    }
}

/// The notification center's delegate, which it calls off the main actor; responses are
/// reduced to plain strings and handed back to the main actor.
private final class Delegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    @MainActor var onResponse: ((_ action: String, _ userInfo: [String: String]) -> Void)?

    /// Shown as a banner even while Kello is frontmost, e.g. with the popover open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String { result[key] = value }
        }
        await MainActor.run { onResponse?(action, userInfo) }
    }
}
