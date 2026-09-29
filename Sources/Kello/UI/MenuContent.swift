import KelloCore
import SwiftUI

/// The menu bar popover: the month grid, then either the permission prompt or the
/// toolbar, today's counts and the agenda.
struct MenuContent: View {
    let openSettings: () -> Void
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars
    @State private var viewModel = MonthGridViewModel()

    private var calendar: Calendar { .current }

    var body: some View {
        // Redrawn every minute so the "now" marker, past events and counts stay current.
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
        .padding(12)
        .frame(width: 308)
        .onAppear { calendars.refreshAccess() }
    }

    private func content(now: Date) -> some View {
        let settings = store.settings
        let grid = MonthGrid.rows(
            year: calendar.component(.year, from: viewModel.referenceDate),
            month: calendar.component(.month, from: viewModel.referenceDate),
            firstWeekday: settings.firstWeekday)
        let gridDays = grid.weeks.flatMap(\.days).map(\.date)
        let gridEvents = events(in: gridDays)
        let agendaDays = Agenda.days(mode: settings.agendaMode, selectedDay: viewModel.selectedDay, now: now)
        let todayEvents = events(in: [now])
        let sections = Agenda.sections(days: agendaDays, events: events(in: agendaDays), reminders: [], now: now)

        return VStack(alignment: .leading, spacing: 8) {
            MonthGridView(viewModel: viewModel, dots: AgendaFormat.dotColors(days: gridDays, events: gridEvents).mapValues { $0.map(Color.init) })
            if calendars.needsPermissionPrompt {
                Divider()
                PermissionView()
            }
            PopoverToolbar(openSettings: openSettings)
            if calendars.eventsAccess == .granted {
                StatusRow(status: AgendaStatus(events: todayEvents, reminders: [], now: now), showsOverdue: false)
                AgendaView(sections: sections, now: now)
            }
        }
    }

    /// The events of visible calendars touching any of `days`, a contiguous run of dates.
    private func events(in days: [Date]) -> [CalendarEvent] {
        guard let first = days.min(), let last = days.max(),
              let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) else { return [] }
        let hidden = store.settings.hiddenCalendarIDs
        return calendars.events(in: DateInterval(start: calendar.startOfDay(for: first), end: end))
            .filter { !hidden.contains($0.calendarID) }
    }
}
