import XCTest
@testable import KelloCore

final class MonthGridTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "UTC")!

    func testGridIsAlways6RowsOf7Days() {
        let grid = MonthGrid.rows(year: 2026, month: 9, firstWeekday: .monday, timeZone: timeZone)
        XCTAssertEqual(grid.weeks.count, 6)
        XCTAssertTrue(grid.weeks.allSatisfy { $0.days.count == 7 })
    }

    /// March 2026 starts on a Sunday. With Monday as the first weekday, the first row is
    /// padded with 6 trailing days of February and March 1st lands on the last cell.
    func testMonthStartingOnSundayWithMondayFirst() {
        let grid = MonthGrid.rows(year: 2026, month: 3, firstWeekday: .monday, timeZone: timeZone)
        let firstRow = grid.weeks[0]
        XCTAssertEqual(firstRow.days.map(\.day), [23, 24, 25, 26, 27, 28, 1])
        XCTAssertEqual(firstRow.days.dropLast().map(\.isInCurrentMonth), [false, false, false, false, false, false])
        XCTAssertTrue(firstRow.days.last!.isInCurrentMonth)
    }

    /// With Sunday as the first weekday, that same March 1st needs no leading padding at
    /// all, since it already falls on the row's first cell.
    func testMonthStartingOnSundayWithSundayFirst() {
        let grid = MonthGrid.rows(year: 2026, month: 3, firstWeekday: .sunday, timeZone: timeZone)
        let firstRow = grid.weeks[0]
        XCTAssertEqual(firstRow.days.map(\.day), [1, 2, 3, 4, 5, 6, 7])
        XCTAssertTrue(firstRow.days.allSatisfy(\.isInCurrentMonth))
        XCTAssertEqual(firstRow.weekNumber, 9)
    }

    /// 2026 has an ISO week 53 (December 28th through January 3rd).
    func testWeek53Exists() {
        let grid = MonthGrid.rows(year: 2026, month: 12, firstWeekday: .monday, timeZone: timeZone)
        let lastFullRow = grid.weeks[4]
        XCTAssertEqual(lastFullRow.days.map(\.day), [28, 29, 30, 31, 1, 2, 3])
        XCTAssertEqual(lastFullRow.weekNumber, 53)
        XCTAssertEqual(lastFullRow.days.suffix(3).map(\.isInCurrentMonth), [false, false, false])
    }

    /// January 2027 opens on a week whose Monday falls in December, so it still carries
    /// the previous ISO year's week number, 53.
    func testJanuaryWeekBelongsToPreviousYear() {
        let grid = MonthGrid.rows(year: 2027, month: 1, firstWeekday: .monday, timeZone: timeZone)
        let firstRow = grid.weeks[0]
        XCTAssertEqual(firstRow.days.map(\.day), [28, 29, 30, 31, 1, 2, 3])
        XCTAssertEqual(firstRow.weekNumber, 53)
        XCTAssertEqual(firstRow.days.prefix(4).map(\.isInCurrentMonth), [false, false, false, false])
        XCTAssertEqual(firstRow.days.suffix(3).map(\.isInCurrentMonth), [true, true, true])
    }
}
