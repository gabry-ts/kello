import Foundation

/// A corner of the outline drawn around the displayed month's days, in cell units: `x` is
/// a column boundary (0...7), `y` a row boundary.
public struct OutlinePoint: Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public extension MonthGrid {
    /// Flat indices (row * 7 + column) of the displayed month's first and last day.
    var monthSpan: ClosedRange<Int>? {
        let days = weeks.flatMap(\.days)
        guard let first = days.firstIndex(where: \.isInCurrentMonth),
              let last = days.lastIndex(where: \.isInCurrentMonth) else { return nil }
        return first...last
    }

    /// The corners, clockwise from the top left of the month's first day, of one polygon
    /// enclosing every day of the displayed month. Its first and last rows are ragged, so
    /// the shape steps in wherever the adjacent months' days sit. Corners that would
    /// coincide or lie on a straight edge are left out, so every one can be rounded.
    var outline: [OutlinePoint] {
        guard let span = monthSpan else { return [] }
        let columns = 7
        let firstRow = span.lowerBound / columns, firstColumn = span.lowerBound % columns
        let lastRow = span.upperBound / columns, lastColumn = span.upperBound % columns

        // A month that fits in a single row is a plain rectangle.
        if firstRow == lastRow {
            return [
                OutlinePoint(x: firstColumn, y: firstRow), OutlinePoint(x: lastColumn + 1, y: firstRow),
                OutlinePoint(x: lastColumn + 1, y: firstRow + 1), OutlinePoint(x: firstColumn, y: firstRow + 1),
            ]
        }

        let raw = [
            OutlinePoint(x: firstColumn, y: firstRow),
            OutlinePoint(x: columns, y: firstRow),
            OutlinePoint(x: columns, y: lastRow),
            OutlinePoint(x: lastColumn + 1, y: lastRow),
            OutlinePoint(x: lastColumn + 1, y: lastRow + 1),
            OutlinePoint(x: 0, y: lastRow + 1),
            OutlinePoint(x: 0, y: firstRow + 1),
            OutlinePoint(x: firstColumn, y: firstRow + 1),
        ]
        return Self.simplified(raw)
    }

    /// Drops repeated corners, then corners between two edges running the same way.
    private static func simplified(_ points: [OutlinePoint]) -> [OutlinePoint] {
        var unique: [OutlinePoint] = []
        for point in points where point != unique.last {
            unique.append(point)
        }
        if unique.count > 1, unique.first == unique.last { unique.removeLast() }

        var result = unique
        var changed = true
        while changed, result.count > 3 {
            changed = false
            for i in result.indices {
                let prev = result[(i + result.count - 1) % result.count]
                let next = result[(i + 1) % result.count]
                let point = result[i]
                if (prev.x == point.x && point.x == next.x) || (prev.y == point.y && point.y == next.y) {
                    result.remove(at: i)
                    changed = true
                    break
                }
            }
        }
        return result
    }
}
