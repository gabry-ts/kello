import KelloCore
import SwiftUI

/// What the popover shows in place of the grid and agenda.
enum EditorRoute: Hashable {
    case event(EventDraft)
    case reminder(ReminderDraft)
}

/// The menu bar popover: the month grid, the permission prompt while needed, the
/// toolbar, today's counts, and the agenda or the reminders. Editors replace all of it while open.
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
        // Reminders only come asynchronously, so they're fetched again on every change.
        .task(id: calendars.revision) { await calendars.loadReminders() }
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
        let todayEvents = events(in: [now])
        let reminders = visibleReminders
        let canReadEvents = calendars.eventsAccess == .granted
        let canReadReminders = calendars.remindersAccess == .granted

        return VStack(alignment: .leading, spacing: 8) {
            MonthGridView(
                viewModel: viewModel,
                dots: AgendaFormat.dotColors(days: gridDays, events: gridEvents).mapValues { $0.map(Color.init) },
                onDoubleClick: canReadEvents ? { newEvent(on: $0, now: now) } : nil)
            if calendars.needsPermissionPrompt {
                Divider()
                PermissionView()
            }
            PopoverToolbar(
                openSettings: openSettings,
                newEvent: canReadEvents ? { newEvent(on: viewModel.selectedDay, now: now) } : nil,
                newReminder: canReadReminders ? { newReminder(on: viewModel.selectedDay) } : nil)
            if canReadEvents || canReadReminders {
                StatusRow(status: AgendaStatus(events: todayEvents, reminders: reminders, now: now), showsOverdue: canReadReminders)
            }
            if canReadReminders && (settings.listTab == .reminders || !canReadEvents) {
                // Overdue and today's reminders, plus the selected day's.
                let days = Array(Set([calendar.startOfDay(for: now), viewModel.selectedDay])).sorted()
                AgendaView(
                    sections: Agenda.sections(days: days, events: [], reminders: reminders, now: now),
                    now: now,
                    emptyText: "No Reminders",
                    openReminder: { route = .reminder(ReminderDraft($0)) },
                    completeReminder: complete)
            } else if canReadEvents {
                let agendaDays = Agenda.days(mode: settings.agendaMode, selectedDay: viewModel.selectedDay, now: now)
                let showsToday = agendaDays.contains { calendar.isDate($0, inSameDayAs: now) }
                AgendaView(
                    sections: Agenda.sections(days: agendaDays, events: events(in: agendaDays), reminders: [], now: now),
                    now: now,
                    nextUp: showsToday ? Agenda.nextUp(events: todayEvents, now: now) : nil,
                    openEvent: { event in
                        if let draft = calendars.draft(for: event) { route = .event(draft) }
                    })
            }
        }
    }

    @ViewBuilder
    private func editor(_ route: EditorRoute) -> some View {
        switch route {
        case .event(let draft):
            EventEditorView(draft: draft) { self.route = nil }
        case .reminder(let draft):
            ReminderEditorView(draft: draft) { self.route = nil }
        }
    }

    private func newReminder(on day: Date) {
        let listID = calendars.defaultReminderListID(hidden: store.settings.hiddenCalendarIDs)
        route = .reminder(ReminderDraft.new(on: day, listID: listID))
    }

    private func complete(_ reminder: ReminderItem) {
        try? calendars.complete(reminder)
    }

    /// Reminders from visible lists.
    private var visibleReminders: [ReminderItem] {
        let hidden = store.settings.hiddenCalendarIDs
        return calendars.reminders.filter { !hidden.contains($0.listID) }
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
