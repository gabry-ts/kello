import KelloCore
import Observation
import PartitiUI
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

    /// Selects `date`'s day and flips the grid to its month, sliding the way it lies.
    func show(_ date: Date) {
        isMovingForward = date >= referenceDate
        referenceDate = date
        selectedDay = Calendar.current.startOfDay(for: date)
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

/// The popover's header: the month and year, with a "‹ Today ›" glass capsule.
struct MonthHeader: View {
    @Bindable var viewModel: MonthGridViewModel
    @Environment(\.puiAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ink = Ink(colorScheme)
        HStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: PUI.Space.xs) {
                Text(viewModel.referenceDate.formatted(.dateTime.month(.wide)))
                    .font(PUI.Font.paneTitle)
                    .foregroundStyle(ink.primary)
                Text(viewModel.referenceDate.formatted(.dateTime.year()))
                    .font(.system(size: 15))
                    .foregroundStyle(ink.secondary)
                    .monospacedDigit()
            }
            .contentTransition(.numericText(countsDown: !viewModel.isMovingForward))
            .padding(.leading, PUI.Space.xs)
            .lineLimit(1)
            Spacer(minLength: PUI.Space.m)
            GlassCapsule {
                IconButton("chevron.left") { viewModel.goToPreviousMonth() }
                    .help("Previous Month")
                Button { viewModel.goToToday() } label: {
                    Text("Today")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent.legible(colorScheme))
                        .padding(.horizontal, PUI.Space.xs)
                        .frame(height: PUI.Control.small)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Today")
                IconButton("chevron.right") { viewModel.goToNextMonth() }
                    .help("Next Month")
            }
        }
        .frame(height: PUI.Control.small)
        .animation(PUI.Motion.spring(reduceMotion: reduceMotion), value: viewModel.referenceDate)
    }
}

/// The month grid shown in the popover: a card with single-letter weekdays and the days,
/// adjacent months dimmed.
struct MonthGridView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: MonthGridViewModel
    /// Up to four calendar colors per day (keyed by start of day), drawn as dots.
    var dots: [Date: [Color]] = [:]
    /// Days with a holiday (as start of day), whose numbers are drawn in red.
    var holidays: Set<Date> = []
    /// Double clicking a day creates an event on it; nil turns it off.
    var onDoubleClick: ((Date) -> Void)?

    static let rowHeight = KelloStyle.cellHeight

    private var calendar: Calendar { .current }

    var body: some View {
        let settings = store.settings
        let year = calendar.component(.year, from: viewModel.referenceDate)
        let month = calendar.component(.month, from: viewModel.referenceDate)
        let grid = MonthGrid.rows(year: year, month: month, firstWeekday: settings.firstWeekday)

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
        .padding(.horizontal, PUI.Space.s)
        .padding(.top, PUI.Space.xs)
        .padding(.bottom, PUI.Space.s)
        .frame(maxWidth: .infinity)
        .puiSurface()
        .animation(PUI.Motion.spring(reduceMotion: reduceMotion), value: viewModel.referenceDate)
    }

    private var monthTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: viewModel.isMovingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: viewModel.isMovingForward ? .leading : .trailing).combined(with: .opacity))
    }

    private func weekdayRow(_ grid: MonthGrid, showWeekNumbers: Bool) -> some View {
        let ink = Ink(colorScheme)
        return HStack(spacing: 0) {
            if showWeekNumbers {
                Color.clear.frame(width: KelloStyle.weekNumberWidth, height: 1)
            }
            ForEach(grid.weeks.first?.days ?? [], id: \.date) { day in
                Text(calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day.date) - 1])
                    .font(PUI.Font.badge)
                    .foregroundStyle(calendar.isDateInWeekend(day.date) ? ink.tertiary : ink.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 18)
    }

    private func monthBody(_ grid: MonthGrid, showWeekNumbers: Bool) -> some View {
        HStack(spacing: 0) {
            if showWeekNumbers {
                VStack(spacing: 0) {
                    ForEach(grid.weeks, id: \.self) { week in
                        Text("\(week.weekNumber)")
                            .font(PUI.Font.badge)
                            .monospacedDigit()
                            .foregroundStyle(Ink(colorScheme).tertiary)
                            .padding(.top, PUI.Space.xs + 1)
                            .frame(width: KelloStyle.weekNumberWidth, height: Self.rowHeight, alignment: .top)
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
    @Environment(\.puiAccent) private var accent
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: PUI.Space.xxs) {
            Text("\(day.day)")
                .font(.system(size: 12, weight: isToday ? .semibold : (isHoliday && day.isInCurrentMonth ? .medium : .regular)))
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .frame(width: KelloStyle.dayCircle, height: KelloStyle.dayCircle)
                .background { circle }
            HStack(spacing: 1.5) {
                ForEach(Array(dots.prefix(4).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: KelloStyle.dotSize, height: KelloStyle.dotSize)
                }
            }
            .frame(height: KelloStyle.dotSize)
            .opacity(day.isInCurrentMonth ? 1 : 0.4)
        }
        .padding(.top, 0.5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(height: MonthGridView.rowHeight)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(PUI.Motion.hover, value: isHovered)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }

    private var numberColor: Color {
        let ink = Ink(colorScheme)
        if isToday { return .white }
        if isHoliday { return KelloStyle.holiday(colorScheme).opacity(day.isInCurrentMonth ? 1 : 0.35) }
        if !day.isInCurrentMonth { return ink.quaternary }
        if isSelected { return accent.legible(colorScheme) }
        return isWeekend ? ink.secondary : ink.primary
    }

    @ViewBuilder
    private var circle: some View {
        let color = accent.color
        if isToday {
            Circle()
                .fill(LinearGradient(colors: [PUI.mix(color, with: .white, by: 0.12), PUI.mix(color, with: .black, by: 0.08)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: color.opacity(0.45), radius: 3, y: 1)
        } else if isSelected {
            Circle()
                .fill(color.opacity(colorScheme == .dark ? 0.22 : 0.13))
                .overlay(Circle().strokeBorder(color.opacity(0.5), lineWidth: 1))
        } else {
            Circle().fill(isHovered ? Ink(colorScheme).strongFill : .clear)
        }
    }
}
