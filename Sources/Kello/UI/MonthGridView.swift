import KelloCore
import Observation
import SwiftUI

/// Which month is displayed and which day is selected. A new instance is created every
/// time the popover opens, so the selection resets to today each time.
@MainActor
@Observable
final class MonthGridViewModel {
    var referenceDate: Date
    var selectedDay: Date?

    init(now: Date = .now) {
        referenceDate = now
        selectedDay = Calendar.current.startOfDay(for: now)
    }

    func goToPreviousMonth() {
        referenceDate = Calendar.current.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
    }

    func goToNextMonth() {
        referenceDate = Calendar.current.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
    }

    func goToToday() {
        referenceDate = .now
        selectedDay = Calendar.current.startOfDay(for: .now)
    }
}

/// The month grid shown in the popover.
struct MonthGridView: View {
    @Environment(SettingsStore.self) private var store
    @State private var viewModel = MonthGridViewModel()

    private var calendar: Calendar { .current }

    var body: some View {
        let settings = store.settings
        let year = calendar.component(.year, from: viewModel.referenceDate)
        let month = calendar.component(.month, from: viewModel.referenceDate)
        let grid = MonthGrid.rows(year: year, month: month, firstWeekday: settings.firstWeekday)

        VStack(alignment: .leading, spacing: 8) {
            header
            weekdayRow(firstWeekday: settings.firstWeekday, showWeekNumbers: settings.showWeekNumbers)
            VStack(spacing: 2) {
                ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                    weekRow(week, showWeekNumber: settings.showWeekNumbers)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(viewModel.referenceDate.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button { viewModel.goToPreviousMonth() } label: {
                Image(systemName: "chevron.left")
            }
            Button("Today") { viewModel.goToToday() }
                .font(.caption)
            Button { viewModel.goToNextMonth() } label: {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.borderless)
    }

    private func weekdayRow(firstWeekday: FirstWeekday, showWeekNumbers: Bool) -> some View {
        HStack(spacing: 2) {
            if showWeekNumbers {
                Color.clear.frame(width: 20)
            }
            ForEach(orderedWeekdaySymbols(firstWeekday), id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekRow(_ week: MonthWeek, showWeekNumber: Bool) -> some View {
        HStack(spacing: 2) {
            if showWeekNumber {
                Text("\(week.weekNumber)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)
            }
            ForEach(week.days, id: \.date) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: MonthDay) -> some View {
        let isToday = calendar.isDateInToday(day.date)
        let isSelected = viewModel.selectedDay.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false
        let textColor: Color = isSelected ? .white : (day.isInCurrentMonth ? .primary : .secondary)
        return Text("\(day.day)")
            .font(.caption)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: 22)
            .background {
                if isSelected {
                    Circle().fill(Color.accentColor)
                } else if isToday {
                    Circle().fill(Color.accentColor.opacity(0.15))
                }
            }
            .contentShape(.rect)
            .onTapGesture { viewModel.selectedDay = day.date }
    }

    /// Weekday abbreviations, in Sunday-first order per `Calendar`, rotated to start on
    /// `firstWeekday`.
    private func orderedWeekdaySymbols(_ firstWeekday: FirstWeekday) -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let firstIndex: Int
        switch firstWeekday {
        case .system: firstIndex = calendar.firstWeekday - 1
        case .monday: firstIndex = 1
        case .sunday: firstIndex = 0
        }
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }
}
