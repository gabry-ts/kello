import KelloCore
import Observation
import SwiftUI

/// Which month is displayed and which day is selected. A new instance is created every
/// time the popover opens, so the selection resets to today each time.
@MainActor
@Observable
final class MonthGridViewModel {
    var referenceDate: Date
    var selectedDay: Date
    /// Which way the last month change went, so the new month slides in from that side.
    private(set) var isMovingForward = true

    init(now: Date = .now) {
        referenceDate = now
        selectedDay = Calendar.current.startOfDay(for: now)
    }

    func goToPreviousMonth() {
        isMovingForward = false
        referenceDate = Calendar.current.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
    }

    func goToNextMonth() {
        isMovingForward = true
        referenceDate = Calendar.current.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
    }

    func goToToday() {
        let now = Date.now
        isMovingForward = now >= referenceDate
        referenceDate = now
        selectedDay = Calendar.current.startOfDay(for: now)
    }

    /// Selecting a day of an adjacent month also flips the grid to that month.
    func select(_ day: MonthDay) {
        selectedDay = Calendar.current.startOfDay(for: day.date)
        if !day.isInCurrentMonth {
            isMovingForward = day.date > referenceDate
            referenceDate = day.date
        }
    }
}

/// The month grid shown in the popover: a header with navigation, single-letter weekday
/// symbols, and the days, with the displayed month enclosed in one rounded outline.
struct MonthGridView: View {
    @Environment(SettingsStore.self) private var store
    @Bindable var viewModel: MonthGridViewModel
    /// Up to four calendar colors per day (keyed by start of day), drawn as dots.
    var dots: [Date: [Color]] = [:]

    static let rowHeight: CGFloat = 34
    private static let weekNumberWidth: CGFloat = 20

    private var calendar: Calendar { .current }

    var body: some View {
        let settings = store.settings
        let year = calendar.component(.year, from: viewModel.referenceDate)
        let month = calendar.component(.month, from: viewModel.referenceDate)
        let grid = MonthGrid.rows(year: year, month: month, firstWeekday: settings.firstWeekday)

        VStack(alignment: .leading, spacing: 6) {
            header
            weekdayRow(grid, showWeekNumbers: settings.showWeekNumbers)
            ZStack {
                monthBody(grid, showWeekNumbers: settings.showWeekNumbers)
                    .id(year * 100 + month)
                    .transition(.asymmetric(
                        insertion: .move(edge: viewModel.isMovingForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: viewModel.isMovingForward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(height: Self.rowHeight * CGFloat(grid.weeks.count))
            .clipped()
        }
        .animation(.smooth(duration: 0.28), value: viewModel.referenceDate)
    }

    private var header: some View {
        HStack(spacing: 2) {
            Text(viewModel.referenceDate.formatted(.dateTime.month(.abbreviated).year()))
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Spacer()
            Button { viewModel.goToPreviousMonth() } label: {
                Image(systemName: "chevron.left")
            }
            .help("Previous Month")
            Button { viewModel.goToToday() } label: {
                Image(systemName: "circle")
                    .font(.system(size: 9, weight: .bold))
            }
            .help("Today")
            Button { viewModel.goToNextMonth() } label: {
                Image(systemName: "chevron.right")
            }
            .help("Next Month")
        }
        .buttonStyle(.icon)
        .padding(.leading, 4)
    }

    private func weekdayRow(_ grid: MonthGrid, showWeekNumbers: Bool) -> some View {
        HStack(spacing: 0) {
            if showWeekNumbers {
                Color.clear.frame(width: Self.weekNumberWidth, height: 1)
            }
            ForEach(grid.weeks.first?.days ?? [], id: \.date) { day in
                Text(calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day.date) - 1])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthBody(_ grid: MonthGrid, showWeekNumbers: Bool) -> some View {
        HStack(spacing: 0) {
            if showWeekNumbers {
                VStack(spacing: 0) {
                    ForEach(grid.weeks, id: \.self) { week in
                        Text("\(week.weekNumber)")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .frame(width: Self.weekNumberWidth, height: Self.rowHeight)
                    }
                }
            }
            VStack(spacing: 0) {
                ForEach(grid.weeks, id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(week.days, id: \.date) { day in
                            DayCell(
                                day: day,
                                isToday: calendar.isDateInToday(day.date),
                                isSelected: calendar.isDate(viewModel.selectedDay, inSameDayAs: day.date),
                                dots: dots[calendar.startOfDay(for: day.date)] ?? []
                            )
                            .onTapGesture { viewModel.select(day) }
                        }
                    }
                }
            }
            .background { weekendBands(grid) }
            .overlay {
                MonthOutlineShape(points: grid.outline, rows: grid.weeks.count)
                    .stroke(.primary.opacity(0.16), lineWidth: 1)
            }
        }
    }

    /// A light rounded band behind each weekend column, the full height of the grid.
    private func weekendBands(_ grid: MonthGrid) -> some View {
        let weekend = (grid.weeks.first?.days ?? []).map { calendar.isDateInWeekend($0.date) }
        return HStack(spacing: 0) {
            ForEach(weekend.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(weekend[index] ? 0.045 : 0))
                    .padding(.horizontal, 1)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// One day: its number, the event dots under it, and today / selection / hover states.
private struct DayCell: View {
    let day: MonthDay
    let isToday: Bool
    let isSelected: Bool
    let dots: [Color]
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 3) {
            Text("\(day.day)")
                .font(.system(size: 12.5, weight: isToday ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(day.isInCurrentMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            HStack(spacing: 2.5) {
                ForEach(Array(dots.prefix(4).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
            .opacity(day.isInCurrentMonth ? 1 : 0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: MonthGridView.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.primary.opacity(isSelected ? 0.11 : (isHovered ? 0.05 : 0)))
                .padding(2.5)
        }
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    .padding(2.5)
            }
        }
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.snappy(duration: 0.18), value: isSelected)
    }
}

/// The outline around the displayed month's days, with every corner, convex or concave,
/// rounded by the same radius.
private struct MonthOutlineShape: Shape {
    let points: [OutlinePoint]
    let rows: Int
    var cornerRadius: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        guard points.count >= 3, rows > 0 else { return Path() }
        // Inset by half the line width so the stroke on the outer edges isn't clipped.
        let rect = rect.insetBy(dx: 0.5, dy: 0.5)
        let cellWidth = rect.width / 7
        let cellHeight = rect.height / CGFloat(rows)
        let corners = points.map { CGPoint(x: rect.minX + CGFloat($0.x) * cellWidth, y: rect.minY + CGFloat($0.y) * cellHeight) }
        let radius = min(cornerRadius, cellWidth / 2, cellHeight / 2)

        var path = Path()
        let last = corners[corners.count - 1]
        path.move(to: CGPoint(x: (last.x + corners[0].x) / 2, y: (last.y + corners[0].y) / 2))
        for i in corners.indices {
            path.addArc(tangent1End: corners[i], tangent2End: corners[(i + 1) % corners.count], radius: radius)
        }
        path.closeSubpath()
        return path
    }
}
