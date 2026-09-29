import XCTest
@testable import KelloCore

final class MeetingAlertsTests: XCTestCase {
    private let blue = ItemColor(red: 0, green: 0, blue: 1)
    private let call = URL(string: "https://meet.google.com/abc-defg-hij")!

    /// Tuesday 29 September 2026, 10:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_790_676_000)

    private func event(_ title: String, inMinutes minutes: Double, allDay: Bool = false, declined: Bool = false,
                       cancelled: Bool = false, link: Bool = true) -> CalendarEvent {
        let start = now.addingTimeInterval(minutes * 60)
        return CalendarEvent(eventIdentifier: title, calendarID: "c", title: title, start: start, end: start.addingTimeInterval(1800),
                             isAllDay: allDay, isDeclined: declined, isCancelled: cancelled, color: blue, meetingURL: link ? call : nil)
    }

    private var enabled: MeetingAlertSettings { MeetingAlertSettings(isEnabled: true) }

    func testNothingWhileDisabled() {
        XCTAssertEqual(MeetingAlerts.upcoming(events: [event("Sync", inMinutes: 30)], now: now, settings: MeetingAlertSettings()), [])
    }

    func testFiresTheChosenMinutesBeforeTheStart() {
        var settings = enabled
        settings.minutesBefore = 10
        let alerts = MeetingAlerts.upcoming(events: [event("Sync", inMinutes: 30)], now: now, settings: settings)
        XCTAssertEqual(alerts.map(\.fireDate), [now.addingTimeInterval(20 * 60)])
    }

    func testSkipsAlertsWhoseTimeHasPassed() {
        // Starts in 3 minutes: a 5 minute alert would already be late.
        XCTAssertEqual(MeetingAlerts.upcoming(events: [event("Soon", inMinutes: 3), event("Started", inMinutes: -5)],
                                              now: now, settings: enabled), [])
    }

    func testOnlyTheNext24Hours() {
        let alerts = MeetingAlerts.upcoming(events: [event("Tomorrow", inMinutes: 23 * 60), event("Later", inMinutes: 25 * 60)],
                                            now: now, settings: enabled)
        XCTAssertEqual(alerts.map(\.event.title), ["Tomorrow"])
    }

    func testSkipsAllDayDeclinedAndCancelledEvents() {
        let events = [
            event("Offsite", inMinutes: 60, allDay: true),
            event("Declined", inMinutes: 60, declined: true),
            event("Cancelled", inMinutes: 60, cancelled: true),
            event("Kept", inMinutes: 60),
        ]
        XCTAssertEqual(MeetingAlerts.upcoming(events: events, now: now, settings: enabled).map(\.event.title), ["Kept"])
    }

    func testMeetingLinkFilter() {
        let events = [event("Call", inMinutes: 60), event("Lunch", inMinutes: 90, link: false)]
        XCTAssertEqual(MeetingAlerts.upcoming(events: events, now: now, settings: enabled).map(\.event.title), ["Call"])
        var everything = enabled
        everything.onlyWithMeetingLink = false
        XCTAssertEqual(MeetingAlerts.upcoming(events: events, now: now, settings: everything).map(\.event.title), ["Call", "Lunch"])
    }

    func testSortedDeduplicatedAndPrefixed() {
        let later = event("Later", inMinutes: 120), sooner = event("Sooner", inMinutes: 60)
        let alerts = MeetingAlerts.upcoming(events: [later, sooner, later], now: now, settings: enabled)
        XCTAssertEqual(alerts.map(\.event.title), ["Sooner", "Later"])
        XCTAssertTrue(alerts.allSatisfy { $0.id.hasPrefix(MeetingAlerts.identifierPrefix) })
        XCTAssertNotEqual(alerts[0].id, alerts[1].id)
    }

    func testOldSettingsFilesDecode() throws {
        let decoded = try JSONDecoder().decode(MeetingAlertSettings.self, from: Data("{\"isEnabled\":true}".utf8))
        XCTAssertEqual(decoded, MeetingAlertSettings(isEnabled: true, minutesBefore: 5, onlyWithMeetingLink: true))
    }
}
