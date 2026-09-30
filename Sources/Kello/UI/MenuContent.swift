import KelloCore
import PartitiUI
import SwiftUI

/// What the popover shows in place of the grid and agenda.
enum EditorRoute: Hashable {
    case event(EventDraft)
    case reminder(ReminderDraft)
    /// A new event typed as one line, in this calendar.
    case quickEntry(calendarID: String)
}

/// The menu bar popover: the month as its header, the grid, the permission prompt while
/// needed, the toolbar, today's counts, the agenda or the reminders, and the footer.
/// Search and the editors replace all of it while open.
struct MenuContent: View {
    let openSettings: () -> Void
    /// Replaces the clock, so snapshots show the same moment every time.
    var fixedNow: Date?
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars
    @Environment(PopoverState.self) private var popover
    @State private var viewModel = MonthGridViewModel()
    @State private var route: EditorRoute?
    @State private var isSearching = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var calendar: Calendar { .current }

    var body: some View {
        ZStack(alignment: .top) {
            if let route {
                editor(route)
                    .popoverFrame()
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            } else if isSearching {
                SearchView(now: fixedNow ?? .now, onClose: { isSearching = false }, onSelect: open)
                    .popoverFrame()
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            } else {
                // Redrawn every minute so the "now" marker, past events and counts stay current.
                TimelineView(.everyMinute) { context in
                    content(now: fixedNow ?? context.date)
                }
                .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(PUI.Motion.spring(reduceMotion: reduceMotion), value: route)
        .animation(PUI.Motion.spring(reduceMotion: reduceMotion), value: isSearching)
        // Reminders only come asynchronously, so they're fetched again on every change.
        .task(id: calendars.revision) { await calendars.loadReminders() }
        .puiAccent(.kello)
        .onAppear { calendars.refreshAccess() }
        .onChange(of: popover.requestedDay, initial: true) { _, day in
            guard let day else { return }
            popover.requestedDay = nil
            route = nil
            isSearching = false
            viewModel.show(day)
        }
    }

    private func content(now: Date) -> some View {
        let settings = store.settings
        let grid = MonthGrid.rows(
            year: calendar.component(.year, from: viewModel.referenceDate),
            month: calendar.component(.month, from: viewModel.referenceDate),
            firstWeekday: settings.firstWeekday)
        let gridDays = grid.weeks.flatMap(\.days).map(\.date)
        let gridEvents = events(in: gridDays)
        let holidayCalendarID = settings.holidayCalendar.resolvedID(among: calendars.eventCalendars)
        let todayEvents = events(in: [now])
        let reminders = visibleReminders
        let canReadEvents = calendars.eventsAccess == .granted
        let canReadReminders = calendars.remindersAccess == .granted

        return PopoverScaffold(width: PUI.Popover.compact) {
            MonthHeader(viewModel: viewModel)
        } content: {
            MonthGridView(
                viewModel: viewModel,
                dots: AgendaFormat.dotColors(days: gridDays, events: gridEvents).mapValues { $0.map(Color.init) },
                holidays: Holidays.days(gridDays, holidays: holidays(in: gridDays, calendarID: holidayCalendarID)),
                onDoubleClick: canReadEvents ? { newEvent(on: $0, now: now) } : nil)
            if calendars.needsPermissionPrompt {
                PermissionView()
            }
            AgendaToolbar(
                search: canReadEvents ? { isSearching = true } : nil,
                newEvent: canReadEvents ? { newEvent(on: viewModel.selectedDay, now: now) } : nil,
                quickEvent: canReadEvents ? { route = .quickEntry(calendarID: defaultCalendarID) } : nil,
                newReminder: canReadReminders ? { newReminder(on: viewModel.selectedDay) } : nil)
            if canReadEvents || canReadReminders {
                StatusRow(status: AgendaStatus(events: todayEvents, reminders: reminders, now: now), showsOverdue: canReadReminders)
            }
            if !settings.timeZones.isEmpty {
                WorldClocksRow(zones: settings.timeZones, now: now)
            }
            if canReadReminders && (settings.listTab == .reminders || !canReadEvents) {
                // Overdue and today's reminders, plus the selected day's.
                let days = Array(Set([calendar.startOfDay(for: now), viewModel.selectedDay])).sorted()
                AgendaView(
                    sections: Agenda.sections(days: days, events: [], reminders: reminders, now: now),
                    now: now,
                    empty: .init(title: String(localized: "No Reminders"), message: String(localized: "Nothing due."),
                                 symbol: "checklist.checked"),
                    fixedHeight: KelloStyle.listHeight,
                    openReminder: { route = .reminder(ReminderDraft($0)) },
                    completeReminder: complete)
            } else if canReadEvents {
                let agendaDays = Agenda.days(mode: settings.agendaMode, selectedDay: viewModel.selectedDay, now: now)
                let showsToday = agendaDays.contains { calendar.isDate($0, inSameDayAs: now) }
                AgendaView(
                    sections: Agenda.sections(days: agendaDays, events: events(in: agendaDays), reminders: [],
                                              holidays: holidays(in: agendaDays, calendarID: holidayCalendarID), now: now),
                    now: now,
                    nextUp: showsToday ? Agenda.nextUp(events: todayEvents, now: now) : nil,
                    fixedHeight: KelloStyle.listHeight,
                    openEvent: { event in
                        if let draft = calendars.draft(for: event) { route = .event(draft) }
                    })
            }
        } footer: {
            KelloFooter(openSettings: openSettings)
        }
    }

    @ViewBuilder
    private func editor(_ route: EditorRoute) -> some View {
        switch route {
        case .event(let draft):
            EventEditorView(draft: draft) { self.route = nil }
        case .reminder(let draft):
            ReminderEditorView(draft: draft) { self.route = nil }
        case .quickEntry(let calendarID):
            QuickEntryView(onClose: { self.route = nil }, onEditDetails: { self.route = .event($0) }, calendarID: calendarID)
        }
    }

    /// A search result: its day selected in the grid, and the event open in the editor.
    private func open(_ event: CalendarEvent) {
        viewModel.show(event.start)
        isSearching = false
        if let draft = calendars.draft(for: event) { route = .event(draft) }
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
        route = .event(EventDraft.new(on: day, now: now, calendarID: defaultCalendarID))
    }

    private var defaultCalendarID: String {
        calendars.defaultCalendarID(hidden: store.settings.hiddenCalendarIDs)
    }

    /// The events of visible calendars touching any of `days`, a contiguous run of dates.
    /// The holidays calendar's are left out, since they're shown as holidays instead.
    private func events(in days: [Date]) -> [CalendarEvent] {
        let hidden = store.settings.hiddenCalendarIDs
        let holidayCalendarID = store.settings.holidayCalendar.resolvedID(among: calendars.eventCalendars)
        return allEvents(in: days).filter { !hidden.contains($0.calendarID) && $0.calendarID != holidayCalendarID }
    }

    /// The holidays touching any of `days`, shown whether or not their calendar is hidden.
    private func holidays(in days: [Date], calendarID: String?) -> [CalendarEvent] {
        guard let calendarID else { return [] }
        return allEvents(in: days).filter { $0.calendarID == calendarID }
    }

    private func allEvents(in days: [Date]) -> [CalendarEvent] {
        guard let first = days.min(), let last = days.max(),
              let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) else { return [] }
        return calendars.events(in: DateInterval(start: calendar.startOfDay(for: first), end: end))
    }
}

extension View {
    /// The popover's width and margin, for search and the editors, which replace the
    /// whole scaffold while open.
    func popoverFrame() -> some View {
        padding(PUI.Popover.margin)
            .frame(width: PUI.Popover.compact)
    }
}
