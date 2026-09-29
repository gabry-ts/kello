import XCTest
@testable import KelloCore

final class EventDraftTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    func testNewEventTodayStartsAtTheNextFullHour() {
        let draft = EventDraft.new(on: date(29, 0), now: date(29, 17, 33), calendarID: "c", calendar: calendar)
        XCTAssertEqual(draft.start, date(29, 18))
        XCTAssertEqual(draft.end, date(29, 19))
        XCTAssertTrue(draft.isNew)
    }

    func testNewEventLateTonightRollsIntoTomorrow() {
        let draft = EventDraft.new(on: date(29, 0), now: date(29, 23, 10), calendarID: "c", calendar: calendar)
        XCTAssertEqual(draft.start, date(30, 0))
    }

    func testNewEventOnAnotherDayKeepsTheHourOfDay() {
        XCTAssertEqual(EventDraft.new(on: date(3, 0), now: date(29, 10, 5), calendarID: "c", calendar: calendar).start, date(3, 11))
        XCTAssertEqual(EventDraft.new(on: date(3, 0), now: date(29, 23, 5), calendarID: "c", calendar: calendar).start, date(3, 23))
    }

    func testAlertOptionFromAlarms() {
        XCTAssertEqual(AlertOption(alarmOffsets: []), .none)
        XCTAssertEqual(AlertOption(alarmOffsets: [0]), .atTime)
        XCTAssertEqual(AlertOption(alarmOffsets: [-900]), .minutes15)
        XCTAssertEqual(AlertOption(alarmOffsets: [-120]), .custom)
        XCTAssertEqual(AlertOption(alarmOffsets: [-300, -600]), .custom)
        XCTAssertEqual(AlertOption(alarmOffsets: [nil]), .custom)
    }

    func testCanSaveAndURLParsing() {
        var draft = EventDraft(calendarID: "c", start: date(29, 10), end: date(29, 9), url: "example.com/x")
        XCTAssertFalse(draft.canSave)
        draft.end = date(29, 11)
        XCTAssertTrue(draft.canSave)
        XCTAssertEqual(draft.parsedURL?.absoluteString, "https://example.com/x")
        draft.url = "  "
        XCTAssertNil(draft.parsedURL)
    }
}
