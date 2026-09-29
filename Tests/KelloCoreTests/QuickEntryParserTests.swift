import XCTest
@testable import KelloCore

final class QuickEntryParserTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Tuesday 29 September 2026, 10:20 UTC.
    private var now: Date { date(9, 29, 10, 20) }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func parse(_ text: String) -> QuickEntry? {
        QuickEntryParser.parse(text, now: now, calendar: calendar)
    }

    private func assertEntry(_ text: String, title: String, start: Date, end: Date, allDay: Bool,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let entry = parse(text) else { return XCTFail("Nothing parsed from \(text)", file: file, line: line) }
        XCTAssertEqual(entry.title, title, text, file: file, line: line)
        XCTAssertEqual(entry.start, start, text, file: file, line: line)
        XCTAssertEqual(entry.end, end, text, file: file, line: line)
        XCTAssertEqual(entry.isAllDay, allDay, text, file: file, line: line)
    }

    func testEnglish() {
        assertEntry("Dentist tomorrow at 3pm", title: "Dentist", start: date(9, 30, 15), end: date(9, 30, 16), allDay: false)
        assertEntry("Call Marco friday 10:00-11:00", title: "Call Marco", start: date(10, 2, 10), end: date(10, 2, 11), allDay: false)
        assertEntry("Holiday 12 oct", title: "Holiday", start: date(10, 12), end: date(10, 12), allDay: true)
        assertEntry("Party on Dec 24 at 8pm", title: "Party", start: date(12, 24, 20), end: date(12, 24, 21), allDay: false)
        assertEntry("Lunch today 12:30", title: "Lunch", start: date(9, 29, 12, 30), end: date(9, 29, 13, 30), allDay: false)
    }

    func testItalian() {
        assertEntry("Dentista domani alle 15", title: "Dentista", start: date(9, 30, 15), end: date(9, 30, 16), allDay: false)
        assertEntry("Chiamare Marco venerdì 10:00-11:00", title: "Chiamare Marco", start: date(10, 2, 10), end: date(10, 2, 11), allDay: false)
        assertEntry("Ferie 12 ottobre", title: "Ferie", start: date(10, 12), end: date(10, 12), allDay: true)
        assertEntry("Cena sabato alle 20:30", title: "Cena", start: date(10, 3, 20, 30), end: date(10, 3, 21, 30), allDay: false)
        // The examples the Italian quick entry suggests.
        assertEntry("Pranzo con Sara venerdì alle 13", title: "Pranzo con Sara", start: date(10, 2, 13), end: date(10, 2, 14), allDay: false)
        assertEntry("Chiamare Marco domani 10:00-11:00", title: "Chiamare Marco", start: date(9, 30, 10), end: date(9, 30, 11), allDay: false)
    }

    func testRangesOfDaysAndAllDay() {
        assertEntry("Trip 3 oct - 5 oct", title: "Trip", start: date(10, 3), end: date(10, 5), allDay: true)
        assertEntry("Gym tomorrow", title: "Gym", start: date(9, 30), end: date(9, 30), allDay: true)
        assertEntry("Offsite tomorrow 3pm all day", title: "Offsite", start: date(9, 30), end: date(9, 30), allDay: true)
    }

    func testDatesWithoutAYearComeNext() {
        assertEntry("Anniversary 5 jan", title: "Anniversary", start: date(1, 5, year: 2027), end: date(1, 5, year: 2027), allDay: true)
        assertEntry("Flight 2027-03-14 07:40", title: "Flight", start: date(3, 14, 7, 40, year: 2027),
                    end: date(3, 14, 8, 40, year: 2027), allDay: false)
    }

    func testWithoutADateStartsAtTheNextHour() {
        assertEntry("Review slides", title: "Review slides", start: date(9, 29, 11), end: date(9, 29, 12), allDay: false)
        XCTAssertNil(parse("   "))
    }

    func testDraft() {
        let draft = parse("Dentist tomorrow at 3pm")!.draft(calendarID: "home")
        XCTAssertEqual(draft.calendarID, "home")
        XCTAssertEqual(draft.title, "Dentist")
        XCTAssertTrue(draft.isNew)
    }
}
