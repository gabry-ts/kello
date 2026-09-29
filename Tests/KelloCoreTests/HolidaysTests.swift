import XCTest
@testable import KelloCore

final class HolidaysTests: XCTestCase {
    private let color = ItemColor(red: 0, green: 0, blue: 0)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 12, day: day, hour: hour))!
    }

    private func info(_ id: String, _ title: String, subscribed: Bool = false) -> CalendarInfo {
        CalendarInfo(id: id, title: title, sourceTitle: "iCloud", color: color, isWritable: !subscribed, isSubscribed: subscribed)
    }

    private func holiday(_ title: String, _ day: Int, days: Int = 1) -> CalendarEvent {
        CalendarEvent(eventIdentifier: title, calendarID: "h", title: title, start: date(day), end: date(day + days), isAllDay: true, color: color)
    }

    func testSuggestsASubscribedHolidaysCalendar() {
        let calendars = [info("work", "Work"), info("mine", "My holidays"), info("it", "Festività italiane", subscribed: true)]
        XCTAssertEqual(Holidays.suggestedCalendarID(among: calendars), "it")
        XCTAssertEqual(Holidays.suggestedCalendarID(among: [info("mine", "Holiday plans"), info("work", "Work")]), "mine")
        XCTAssertEqual(Holidays.suggestedCalendarID(among: [info("g", "Festivita in Italia")]), "g")
        XCTAssertNil(Holidays.suggestedCalendarID(among: [info("work", "Work")]))
    }

    func testChoiceResolution() {
        let calendars = [info("work", "Work"), info("us", "US Holidays", subscribed: true)]
        XCTAssertEqual(HolidayCalendarChoice.automatic.resolvedID(among: calendars), "us")
        XCTAssertNil(HolidayCalendarChoice.none.resolvedID(among: calendars))
        XCTAssertEqual(HolidayCalendarChoice.calendar("work").resolvedID(among: calendars), "work")
        XCTAssertNil(HolidayCalendarChoice.calendar("gone").resolvedID(among: calendars))
    }

    func testDaysAndNames() {
        let holidays = [holiday("Christmas Day", 25), holiday("Boxing Day", 26), holiday("Winter Break", 24, days: 3)]
        let days = Holidays.days([date(23), date(24, 12), date(26), date(27)], holidays: holidays, calendar: calendar)
        XCTAssertEqual(days, [date(24), date(26)])
        XCTAssertEqual(Holidays.names(in: DateInterval(start: date(26), end: date(27)), holidays: holidays), ["Winter Break", "Boxing Day"])
    }

    func testAgendaShowsHolidaysEvenOnOtherwiseEmptyDays() {
        let now = date(20, 10)
        let sections = Agenda.sections(days: [date(25)], events: [], reminders: [], holidays: [holiday("Christmas Day", 25)],
                                       now: now, calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].holidays, ["Christmas Day"])
        XCTAssertTrue(sections[0].entries.isEmpty)
    }
}
