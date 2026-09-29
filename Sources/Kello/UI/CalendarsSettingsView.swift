import KelloCore
import SwiftUI

/// Calendars settings: the holidays calendar, then every calendar and reminder list,
/// grouped by account, with a toggle to show or hide it in the popover.
struct CalendarsSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars

    var body: some View {
        Form {
            PaneHeader(pane: .calendars, subtitle: "Choose which calendars and reminder lists appear in the menu bar.")
            if calendars.eventsAccess != .granted {
                Section {
                    Text("Allow Kello to access your calendars to choose which ones to show.")
                        .foregroundStyle(.secondary)
                    Button("Open Privacy Settings…") { calendars.openPrivacySettings(for: .event) }
                        .buttonStyle(.glass)
                }
            } else {
                Section {
                    holidayPicker
                } header: {
                    Text("Holidays")
                } footer: {
                    Text("Days with an event in this calendar get a red number in the grid, and the holiday's name shows above that day's agenda.")
                        .foregroundStyle(.secondary)
                }
            }
            // Calendars and reminder lists can share an account name, so each section is
            // keyed by kind as well.
            ForEach(sections, id: \.id) { section in
                Section(section.title) {
                    ForEach(section.calendars) { calendar in
                        CalendarToggle(calendar: calendar)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Shows the automatic pick until one is chosen; choosing "None" turns holidays off.
    private var holidayPicker: some View {
        let all = calendars.eventCalendars
        let selection = Binding<String>(
            get: { store.settings.holidayCalendar.resolvedID(among: all) ?? "" },
            set: { store.settings.holidayCalendar = $0.isEmpty ? .none : .calendar($0) })
        return Picker("Holidays calendar", selection: selection) {
            Text("None").tag("")
            ForEach(CalendarGroup.grouped(all)) { group in
                Section(group.sourceTitle) {
                    ForEach(group.calendars) { calendar in
                        Label { Text(calendar.title) } icon: { Image(nsImage: .swatch(calendar.color)) }
                            .tag(calendar.id)
                    }
                }
            }
        }
    }

    private var sections: [(id: String, title: String, calendars: [CalendarInfo])] {
        CalendarGroup.grouped(calendars.eventCalendars).map { ("e|\($0.id)", $0.sourceTitle, $0.calendars) }
            + CalendarGroup.grouped(calendars.reminderLists).map {
                ("r|\($0.id)", String(localized: "Reminders · \($0.sourceTitle)"), $0.calendars)
            }
    }
}

/// A calendar's color swatch, title and visibility toggle.
struct CalendarToggle: View {
    @Environment(SettingsStore.self) private var store
    let calendar: CalendarInfo

    var body: some View {
        Toggle(isOn: Binding(
            get: { store.settings.isCalendarVisible(calendar.id) },
            set: { store.settings.setCalendar(calendar.id, visible: $0) }
        )) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(calendar.color).gradient)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 0.5))
                Text(calendar.title)
            }
        }
    }
}

/// The quick picker in the popover's "more" menu: the same toggles, as a submenu grouped
/// by account, calendars first and then reminder lists.
struct CalendarVisibilityMenu: View {
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars

    var body: some View {
        Menu {
            groups(calendars.eventCalendars)
            let lists = calendars.reminderLists
            if !lists.isEmpty {
                Divider()
                Text("Reminder Lists")
                groups(lists)
            }
        } label: {
            Label("Calendars", systemImage: "calendar.badge.checkmark")
        }
    }

    private func groups(_ items: [CalendarInfo]) -> some View {
        ForEach(CalendarGroup.grouped(items)) { group in
            Section(group.sourceTitle) {
                ForEach(group.calendars) { calendar in
                    Toggle(isOn: Binding(
                        get: { store.settings.isCalendarVisible(calendar.id) },
                        set: { store.settings.setCalendar(calendar.id, visible: $0) }
                    )) {
                        Label { Text(calendar.title) } icon: { Image(nsImage: .swatch(calendar.color)) }
                    }
                }
            }
        }
    }
}
