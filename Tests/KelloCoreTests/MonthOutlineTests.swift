import XCTest
@testable import KelloCore

final class MonthOutlineTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "UTC")!

    private func points(_ pairs: [(Int, Int)]) -> [OutlinePoint] {
        pairs.map { OutlinePoint(x: $0.0, y: $0.1) }
    }

    /// September 2026 runs Tuesday 1st to Wednesday 30th, so both ends are ragged.
    func testRaggedFirstAndLastRows() {
        let grid = MonthGrid.rows(year: 2026, month: 9, firstWeekday: .monday, timeZone: timeZone)
        XCTAssertEqual(grid.monthSpan, 1...30)
        XCTAssertEqual(grid.outline, points([(1, 0), (7, 0), (7, 4), (3, 4), (3, 5), (0, 5), (0, 1), (1, 1)]))
    }

    /// March 2026 starts on the first cell with Sunday first, so the top left is square.
    func testMonthStartingOnFirstColumn() {
        let grid = MonthGrid.rows(year: 2026, month: 3, firstWeekday: .sunday, timeZone: timeZone)
        XCTAssertEqual(grid.outline, points([(0, 0), (7, 0), (7, 4), (3, 4), (3, 5), (0, 5)]))
    }

    /// February 2015 fills exactly four rows starting on a Sunday: a plain rectangle.
    func testMonthFillingWholeRows() {
        let grid = MonthGrid.rows(year: 2015, month: 2, firstWeekday: .sunday, timeZone: timeZone)
        XCTAssertEqual(grid.outline, points([(0, 0), (7, 0), (7, 4), (0, 4)]))
    }

    /// Ending on the last column drops the step on the bottom right.
    func testMonthEndingOnLastColumn() {
        // May 2026: Friday 1st to Sunday 31st, Monday first.
        let grid = MonthGrid.rows(year: 2026, month: 5, firstWeekday: .monday, timeZone: timeZone)
        XCTAssertEqual(grid.outline, points([(4, 0), (7, 0), (7, 5), (0, 5), (0, 1), (4, 1)]))
    }
}
