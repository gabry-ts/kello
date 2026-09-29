import XCTest
@testable import KelloCore

final class EventMatcherTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private let color = ItemColor(red: 0, green: 0, blue: 1)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = locale
        return calendar
    }

    /// Tuesday 29 September 2026, 10:00 UTC.
    private var now: Date { date(9, 29, 10) }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 9, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func event(_ title: String, _ start: Date, location: String? = nil, notes: String? = nil) -> CalendarEvent {
        CalendarEvent(eventIdentifier: title, calendarID: "c", title: title, start: start, end: start.addingTimeInterval(3600),
                      location: location, notes: notes, color: color)
    }

    func testMatchesTitleLocationAndNotesIgnoringCaseAndAccents() {
        let lunch = event("Pranzo con Sara", now, location: "Caffè Nazionale", notes: "Bring the Q4 slides")
        XCTAssertTrue(EventMatcher(query: "pranzo").matches(lunch))
        XCTAssertTrue(EventMatcher(query: "CAFFE").matches(lunch))
        XCTAssertTrue(EventMatcher(query: "q4 SLIDES").matches(lunch))
        XCTAssertTrue(EventMatcher(query: "sara caffè").matches(lunch))
        XCTAssertFalse(EventMatcher(query: "sara dinner").matches(lunch))
        XCTAssertFalse(EventMatcher(query: "   ").matches(lunch))
        XCTAssertTrue(EventMatcher(query: "  ").isEmpty)
    }

    func testGroupsUpcomingDaysFirstThenPastDaysMostRecentFirst() {
        let events = [
            event("Standup", date(9, 28)),
            event("Standup", date(10, 1)),
            event("Standup", date(9, 29, 8)),
            event("Standup", date(1, 4, year: 2027)),
            event("Standup", date(9, 1)),
            event("Standup late", date(10, 1, 15)),
            event("Lunch", date(9, 30)),
        ]
        let sections = EventMatcher(query: "standup").sections(in: events, now: now, calendar: calendar, locale: locale)
        XCTAssertEqual(sections.map(\.title), ["Today", "Thu, Oct 1", "Mon, Jan 4, 2027", "Yesterday", "Tue, Sep 1"])
        XCTAssertEqual(sections[1].entries.map(\.id), [events[1].id, events[5].id].map { "e|\($0)" })
    }

    func testLimitKeepsUpcomingBeforePast() {
        // Sep 26 and 28 are past; Sep 30, Oct 2 and Oct 4 are ahead.
        let events = [date(9, 26), date(9, 28), date(9, 30), date(10, 2), date(10, 4)].map { event("Gym", $0) }
        let sections = EventMatcher(query: "gym").sections(in: events, now: now, limit: 4, calendar: calendar, locale: locale)
        XCTAssertEqual(sections.map(\.title), ["Tomorrow", "Fri, Oct 2", "Sun, Oct 4", "Yesterday"])
    }
}
