import XCTest
@testable import KelloCore

final class ReminderDraftTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let due = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21 14:13:20 UTC

    func testDueComponentsWithAndWithoutTime() {
        var draft = ReminderDraft(listID: "l", title: "Call", due: due)
        let dateOnly = draft.dueComponents(calendar: calendar)
        XCTAssertEqual([dateOnly?.year, dateOnly?.month, dateOnly?.day], [2026, 9, 21])
        XCTAssertNil(dateOnly?.hour)
        draft.hasDueTime = true
        XCTAssertEqual(draft.dueComponents(calendar: calendar)?.hour, 14)
        draft.hasDueDate = false
        XCTAssertNil(draft.dueComponents(calendar: calendar))
    }

    func testCanSaveNeedsATitleAndAList() {
        XCTAssertFalse(ReminderDraft(listID: "l", title: "  ", due: due).canSave)
        XCTAssertFalse(ReminderDraft(listID: "", title: "Call", due: due).canSave)
        XCTAssertTrue(ReminderDraft(listID: "l", title: "Call", due: due).canSave)
    }

    func testPriorityBuckets() {
        XCTAssertEqual(ReminderPriority(eventKitValue: 0), .none)
        XCTAssertEqual(ReminderPriority(eventKitValue: 3), .high)
        XCTAssertEqual(ReminderPriority(eventKitValue: 5), .medium)
        XCTAssertEqual(ReminderPriority(eventKitValue: 9), .low)
    }

    func testNewReminderIsDueOnTheDayWithoutATime() {
        let draft = ReminderDraft.new(on: due, listID: "l", calendar: calendar)
        XCTAssertTrue(draft.hasDueDate)
        XCTAssertFalse(draft.hasDueTime)
        XCTAssertEqual(calendar.component(.hour, from: draft.due), 0)
    }
}
