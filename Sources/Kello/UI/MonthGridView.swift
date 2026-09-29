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

/// The month grid shown in the popover: the month and year with a "‹ Today ›" pill, then
/// a glass card with single-letter weekdays and the days, adjacent months dimmed.
struct MonthGridView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: MonthGridViewModel
    /// Up to four calendar colors per day (keyed by start of day), drawn as dots.
    var dots: [Date: [Color]] = [:]
    /// Days with a holiday (as start of day), whose numbers are drawn in red.
    var holidays: Set<Date> = []
    /// Double clicking a day creates an event on it; nil turns it off.
    var onDoubleClick: ((Date) -> Void)?

    static let rowHeight = Theme.cellHeight
    private static let weekNumberWidth: CGFloat = 20
    private static let cardPadding: CGFloat = 8

    private var calendar: Calendar { .current }

    var body: some View {
        let settings = store.settings
        let year = calendar.component(.year, from: viewModel.referenceDate)
        let month = calendar.component(.month, from: viewModel.referenceDate)
        let grid = MonthGrid.rows(year: year, month: month, firstWeekday: settings.firstWeekday)

        VStack(alignment: .leading, spacing: Theme.spacing) {
            header
            VStack(spacing: 0) {
                weekdayRow(grid, showWeekNumbers: settings.showWeekNumbers)
                ZStack {
                    monthBody(grid, showWeekNumbers: settings.showWeekNumbers)
                        .id(year * 100 + month)
                        .transition(monthTransition)
                }
                .frame(height: Self.rowHeight * CGFloat(grid.weeks.count), alignment: .top)
                .clipped()
            }
            .padding(.horizontal, Self.cardPadding)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .surface()
        }
        .animation(Theme.spring(reduceMotion), value: viewModel.referenceDate)
    }

    private var monthTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: viewModel.isMovingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: viewModel.isMovingForward ? .leading : .trailing).combined(with: .opacity))
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(viewModel.referenceDate.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 20, weight: .bold))
                Text(viewModel.referenceDate.formatted(.dateTime.year()))
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentTransition(.numericText(countsDown: !viewModel.isMovingForward))
            .padding(.leading, 4)
            .lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                Button { viewModel.goToPreviousMonth() } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Previous Month")
                Button { viewModel.goToToday() } label: {
                    Text("Today")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 6)
                }
                .help("Today")
                Button { viewModel.goToNextMonth() } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Next Month")
            }
            .buttonStyle(.icon)
            .padding(1)
            .glassEffect(.regular, in: .capsule)
            .glassEdge(Capsule())
        }
        .frame(height: Theme.controlSize)
    }

    private func weekdayRow(_ grid: MonthGrid, showWeekNumbers: Bool) -> some View {
        HStack(spacing: 0) {
            if showWeekNumbers {
                Color.clear.frame(width: Self.weekNumberWidth, height: 1)
            }
            ForEach(grid.weeks.first?.days ?? [], id: \.date) { day in
                Text(calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day.date) - 1])
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(calendar.isDateInWeekend(day.date) ? .tertiary : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 24)
    }

    private func monthBody(_ grid: MonthGrid, showWeekNumbers: Bool) -> some View {
        HStack(spacing: 0) {
            if showWeekNumbers {
                VStack(spacing: 0) {
                    ForEach(grid.weeks, id: \.self) { week in
                        Text("\(week.weekNumber)")
                            .font(.system(size: 9.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .frame(width: Self.weekNumberWidth, height: Self.rowHeight, alignment: .top)
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
                                isWeekend: calendar.isDateInWeekend(day.date),
                                isSelected: calendar.isDate(viewModel.selectedDay, inSameDayAs: day.date),
                                isHoliday: holidays.contains(calendar.startOfDay(for: day.date)),
                                dots: dots[calendar.startOfDay(for: day.date)] ?? []
                            )
                            .onTapGesture { viewModel.select(day) }
                            // Simultaneous, so the first click still selects right away
                            // instead of waiting out the double-click interval.
                            .simultaneousGesture(TapGesture(count: 2).onEnded { onDoubleClick?(day.date) })
                        }
                    }
                }
            }
        }
    }
}

/// One day: its number in a circle (filled for today, ringed when selected), red on
/// holidays, the event dots under it, and a hover state.
private struct DayCell: View {
    let day: MonthDay
    let isToday: Bool
    let isWeekend: Bool
    let isSelected: Bool
    let isHoliday: Bool
    let dots: [Color]
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 3) {
            Text("\(day.day)")
                .font(.system(size: 13, weight: isToday ? .semibold : (isHoliday && day.isInCurrentMonth ? .medium : .regular)))
                .monospacedDigit()
                .foregroundStyle(numberStyle)
                .frame(width: Theme.dayCircle, height: Theme.dayCircle)
                .background { circle }
            HStack(spacing: 2) {
                ForEach(Array(dots.prefix(4).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: Theme.dotSize, height: Theme.dotSize)
                }
            }
            .frame(height: Theme.dotSize)
            .opacity(day.isInCurrentMonth ? 1 : 0.4)
        }
        .padding(.top, 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(height: MonthGridView.rowHeight)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(Theme.hover, value: isHovered)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }

    private var numberStyle: AnyShapeStyle {
        if isToday { return AnyShapeStyle(.white) }
        if isHoliday { return AnyShapeStyle(Theme.holiday.opacity(day.isInCurrentMonth ? 1 : 0.35)) }
        if !day.isInCurrentMonth { return AnyShapeStyle(.quaternary) }
        if isSelected { return AnyShapeStyle(.tint) }
        return isWeekend ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
    }

    @ViewBuilder
    private var circle: some View {
        if isToday {
            Circle()
                .fill(Color.accentColor.gradient)
                .shadow(color: .accentColor.opacity(0.45), radius: 4, y: 1.5)
        } else if isSelected {
            Circle()
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.13))
                .overlay(Circle().strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1))
        } else {
            Circle().fill(.primary.opacity(isHovered ? 0.07 : 0))
        }
    }
}
