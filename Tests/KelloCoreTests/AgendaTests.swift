import XCTest
@testable import KelloCore

final class AgendaTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private let blue = ItemColor(red: 0, green: 0, blue: 1)
    private let red = ItemColor(red: 1, green: 0, blue: 0)
    private let green = ItemColor(red: 0, green: 1, blue: 0)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = locale
        return calendar
    }

    /// Tuesday 29 September 2026, 10:00 UTC.
    private var now: Date { date(29, 10) }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false, color: ItemColor? = nil) -> CalendarEvent {
        CalendarEvent(eventIdentifier: title, calendarID: "c", title: title, start: start, end: end, isAllDay: allDay, color: color ?? blue)
    }

    private func reminder(_ title: String, due: Date?, hasTime: Bool = true) -> ReminderItem {
        ReminderItem(id: title, listID: "l", title: title, due: due, hasDueTime: hasTime, color: red)
    }

    private func title(_ day: Date) -> String {
        Agenda.sectionTitle(for: day, now: now, calendar: calendar, locale: locale)
    }

    func testRelativeSectionTitles() {
        XCTAssertEqual(title(date(29, 0)), "Today")
        XCTAssertEqual(title(date(28, 23)), "Yesterday")
        XCTAssertEqual(title(date(30, 1)), "Tomorrow")
        XCTAssertEqual(title(date(26, 12)), "3 days ago")
        XCTAssertEqual(title(date(15, 12)), "2 weeks ago")
        XCTAssertEqual(title(date(8, 12)), "3 weeks ago")
        XCTAssertEqual(title(date(2, 12, month: 10)), "Friday")
        XCTAssertEqual(title(date(8, 12, month: 10)), "Thu, Oct 8")
        XCTAssertEqual(title(date(10, 12, month: 6)), "3 months ago")
    }

    func testDayModeGroupsOverdueRemindersThenToday() {
        let events = [
            event("Standup", date(29, 9), date(29, 9, 15)),
            event("Lunch", date(29, 12), date(29, 13)),
            event("Holiday", date(29, 0), date(30, 0), allDay: true),
            event("Tomorrow", date(30, 9), date(30, 10)),
        ]
        let reminders = [
            reminder("Old", due: date(8, 9)),
            reminder("Older", due: date(7, 9)),
            reminder("Yesterday", due: date(28, 9)),
            reminder("Due today", due: date(29, 8)),
            reminder("Undated", due: nil),
        ]
        let sections = Agenda.sections(days: [now], events: events, reminders: reminders, now: now, calendar: calendar, locale: locale)
        XCTAssertEqual(sections.map(\.title), ["3 weeks ago", "Yesterday", "Today"])
        XCTAssertEqual(sections[0].entries.map(\.id), ["r|Older", "r|Old"])
        XCTAssertEqual(sections[2].entries.map(\.id), [
            "r|Due today", events[2].id.prefixed("e|"), events[0].id.prefixed("e|"), "now", events[1].id.prefixed("e|"),
        ])
        XCTAssertEqual(sections[2].entries[3], .now(untilNext: 2 * 3600))
    }

    func testOtherDaysSkipOverdueAndTheNowMarker() {
        let events = [event("Tomorrow", date(30, 9), date(30, 10))]
        let reminders = [reminder("Old", due: date(8, 9))]
        let sections = Agenda.sections(days: [date(30, 0)], events: events, reminders: reminders, now: now, calendar: calendar, locale: locale)
        XCTAssertEqual(sections.map(\.title), ["Tomorrow"])
        XCTAssertEqual(sections[0].entries.count, 1)
    }

    func testUpcomingSkipsEmptyDaysAndCoversAWeek() {
        let days = Agenda.days(mode: .upcoming, selectedDay: date(3, 0), now: now, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, date(29, 0))
        let events = [event("A", date(1, 9, month: 10), date(1, 10, month: 10)), event("Late", date(9, 9, month: 10), date(9, 10, month: 10))]
        let sections = Agenda.sections(days: days, events: events, reminders: [], now: now, calendar: calendar, locale: locale)
        XCTAssertEqual(sections.map(\.title), ["Thursday"])
    }

    func testMultiDayEventAppearsOnEveryDayButNotAfterItEnds() {
        let trip = event("Trip", date(29, 0), date(1, 0, month: 10), allDay: true)
        let days = [date(29, 0), date(30, 0), date(1, 0, month: 10)]
        let sections = Agenda.sections(days: days, events: [trip], reminders: [], now: now, calendar: calendar, locale: locale)
        XCTAssertEqual(sections.map(\.title), ["Today", "Tomorrow"])
    }

    func testOverdueAge() {
        XCTAssertEqual(AgendaFormat.overdueAge(since: now.addingTimeInterval(-(25 * 86400 + 23 * 3600 + 120)), now: now), "25d 23h ago")
        XCTAssertEqual(AgendaFormat.overdueAge(since: now.addingTimeInterval(-(3 * 3600 + 12 * 60)), now: now), "3h 12m ago")
        XCTAssertEqual(AgendaFormat.overdueAge(since: now.addingTimeInterval(-720), now: now), "12m ago")
        XCTAssertEqual(AgendaFormat.overdueAge(since: now.addingTimeInterval(-20), now: now), "now")
        XCTAssertEqual(AgendaFormat.compactDuration(2 * 86400), "2d")
        XCTAssertEqual(AgendaFormat.compactDuration(3600), "1h")
    }

    func testTimeRange() {
        XCTAssertEqual(AgendaFormat.timeRange(start: date(29, 0), end: date(30, 0), isAllDay: true, calendar: calendar, locale: locale), "All day")
        let timed = AgendaFormat.timeRange(start: date(29, 11), end: date(29, 11, 30), isAllDay: false, calendar: calendar, locale: locale)
        XCTAssertTrue(timed.hasPrefix("11:00"), timed)
        XCTAssertTrue(timed.hasSuffix("11:30\u{202F}AM (GMT)"), timed)
        let span = AgendaFormat.timeRange(start: date(29, 0), end: date(2, 0, month: 10), isAllDay: true, calendar: calendar, locale: locale)
        XCTAssertTrue(span.contains("Sep 29") && span.contains("Oct 1"), span)
    }

    func testDotColorsAreDistinctOrderedAndCapped() {
        let yellow = ItemColor(red: 1, green: 1, blue: 0), gray = ItemColor(red: 0.5, green: 0.5, blue: 0.5)
        let events = [
            event("b", date(29, 12), date(29, 13), color: red),
            event("a", date(29, 9), date(29, 10), color: blue),
            event("c", date(29, 14), date(29, 15), color: blue),
            event("d", date(29, 15), date(29, 16), color: green),
            event("e", date(29, 16), date(29, 17), color: yellow),
            event("f", date(29, 17), date(29, 18), color: gray),
            event("midnight", date(28, 23), date(29, 0), color: gray),
        ]
        let dots = AgendaFormat.dotColors(days: [date(28, 0), date(29, 0), date(30, 0)], events: events, calendar: calendar)
        XCTAssertEqual(dots[date(29, 0)], [blue, red, green, yellow])
        XCTAssertEqual(dots[date(28, 0)], [gray])
        XCTAssertNil(dots[date(30, 0)])
    }

    func testStatusCounts() {
        let events = [event("a", date(29, 9), date(29, 10), color: red), event("b", date(29, 11), date(29, 12), color: red),
                      event("c", date(29, 13), date(29, 14), color: green), event("x", date(30, 9), date(30, 10))]
        let reminders = [reminder("late", due: date(29, 8)), reminder("dateOnly", due: date(29, 0), hasTime: false),
                         reminder("old", due: date(20, 0), hasTime: false), reminder("later", due: date(29, 18))]
        let status = AgendaStatus(events: events, reminders: reminders, now: now, calendar: calendar)
        XCTAssertEqual(status.overdueCount, 2)
        XCTAssertEqual(status.todayCount, 3)
        XCTAssertEqual(status.todayColors, [red, green])
    }

    func testSubtitlePrefersLocationThenFirstNotesLine() {
        let withLocation = CalendarEvent(eventIdentifier: "1", calendarID: "c", title: "t", start: now, end: now,
                                         location: " Room 4 ", notes: "Agenda", color: blue)
        XCTAssertEqual(withLocation.subtitle, "Room 4")
        let withNotes = CalendarEvent(eventIdentifier: "2", calendarID: "c", title: "t", start: now, end: now,
                                      location: "", notes: "\n  First line\nSecond", color: blue)
        XCTAssertEqual(withNotes.subtitle, "First line")
    }

    func testMeetingLinkDetection() {
        XCTAssertEqual(MeetingLink.find(in: [nil, "Join: https://us02web.zoom.us/j/123?pwd=x"])?.host(), "us02web.zoom.us")
        XCTAssertEqual(MeetingLink.find(in: ["https://meet.google.com/abc-defg-hij"])?.absoluteString, "https://meet.google.com/abc-defg-hij")
        XCTAssertNil(MeetingLink.find(in: ["https://example.com/zoom.us", "Room 4"]))
    }
}

private extension String {
    func prefixed(_ prefix: String) -> String { prefix + self }
}
