import Foundation

/// When to be told about upcoming meetings.
public struct MeetingAlertSettings: Codable, Hashable, Sendable {
    /// The choices offered for how early the alert comes, in minutes.
    public static let leadTimes = [1, 2, 5, 10, 15]

    public var isEnabled = false
    public var minutesBefore = 5
    /// Only events with a video call link, which is what most people want a heads-up for.
    public var onlyWithMeetingLink = true

    public init(isEnabled: Bool = false, minutesBefore: Int = 5, onlyWithMeetingLink: Bool = true) {
        self.isEnabled = isEnabled
        self.minutesBefore = minutesBefore
        self.onlyWithMeetingLink = onlyWithMeetingLink
    }

    /// Missing keys fall back to defaults, so settings files from older versions still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MeetingAlertSettings()
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? d.isEnabled
        minutesBefore = try c.decodeIfPresent(Int.self, forKey: .minutesBefore) ?? d.minutesBefore
        onlyWithMeetingLink = try c.decodeIfPresent(Bool.self, forKey: .onlyWithMeetingLink) ?? d.onlyWithMeetingLink
    }
}

/// One alert to schedule: the event and when to fire.
public struct MeetingAlert: Hashable, Sendable, Identifiable {
    /// Stable per occurrence and lead time, so rescheduling finds the alerts it already made.
    public var id: String { "\(MeetingAlerts.identifierPrefix)\(event.id)|\(Int(event.start.timeIntervalSince(fireDate)))" }
    public let event: CalendarEvent
    public let fireDate: Date

    public init(event: CalendarEvent, fireDate: Date) {
        self.event = event
        self.fireDate = fireDate
    }
}

/// Picks which events get an alert ahead of their start.
public enum MeetingAlerts {
    /// Every pending notification Kello schedules starts with this, so stale ones can be
    /// told apart from anything else and removed.
    public static let identifierPrefix = "kello.meeting."

    /// How far ahead alerts are scheduled; rescheduling at least hourly keeps it topped up.
    public static let horizon: TimeInterval = 24 * 60 * 60

    /// Timed events starting within `horizon` of `now` whose alert time is still ahead,
    /// sorted by when they fire. All-day, declined and cancelled events never alert.
    public static func upcoming(events: [CalendarEvent], now: Date, settings: MeetingAlertSettings) -> [MeetingAlert] {
        guard settings.isEnabled else { return [] }
        let lead = TimeInterval(settings.minutesBefore * 60)
        var seen: Set<String> = []
        return events
            .filter { event in
                !event.isAllDay && !event.isDeclined && !event.isCancelled
                    && event.start > now && event.start <= now.addingTimeInterval(horizon)
                    && event.start.addingTimeInterval(-lead) > now
                    && (!settings.onlyWithMeetingLink || event.meetingURL != nil)
            }
            .map { MeetingAlert(event: $0, fireDate: $0.start.addingTimeInterval(-lead)) }
            // The same occurrence can come back twice from overlapping fetches.
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.fireDate, $0.event.title) < ($1.fireDate, $1.event.title) }
    }
}
