import KelloCore
import SwiftUI

/// What the popover shows in place of the grid and agenda.
enum EditorRoute: Hashable {
    case event(EventDraft)
}

/// The menu bar popover: the month grid, then either the permission prompt or the
/// toolbar, today's counts and the agenda. Editors replace all of it while open.
struct MenuContent: View {
    let openSettings: () -> Void
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars
    @State private var viewModel = MonthGridViewModel()
    @State private var route: EditorRoute?

    private var calendar: Calendar { .current }

    var body: some View {
        ZStack(alignment: .top) {
            if let route {
                editor(route)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // Redrawn every minute so the "now" marker, past events and counts stay current.
                TimelineView(.everyMinute) { context in
                    content(now: context.date)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.25), value: route)
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
            MonthGridView(
                viewModel: viewModel,
                dots: AgendaFormat.dotColors(days: gridDays, events: gridEvents).mapValues { $0.map(Color.init) },
                onDoubleClick: calendars.eventsAccess == .granted ? { newEvent(on: $0, now: now) } : nil)
            if calendars.needsPermissionPrompt {
                Divider()
                PermissionView()
            }
            PopoverToolbar(openSettings: openSettings, newEvent: calendars.eventsAccess == .granted ? { newEvent(on: viewModel.selectedDay, now: now) } : nil)
            if calendars.eventsAccess == .granted {
                StatusRow(status: AgendaStatus(events: todayEvents, reminders: [], now: now), showsOverdue: false)
                AgendaView(sections: sections, now: now) { event in
                    if let draft = calendars.draft(for: event) { route = .event(draft) }
                }
            }
        }
    }

    @ViewBuilder
    private func editor(_ route: EditorRoute) -> some View {
        switch route {
        case .event(let draft):
            EventEditorView(draft: draft) { self.route = nil }
        }
    }

    private func newEvent(on day: Date, now: Date) {
        let calendarID = calendars.defaultCalendarID(hidden: store.settings.hiddenCalendarIDs)
        route = .event(EventDraft.new(on: day, now: now, calendarID: calendarID))
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
