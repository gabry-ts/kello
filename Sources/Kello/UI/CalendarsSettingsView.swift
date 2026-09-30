import KelloCore
import PartitiUI
import SwiftUI

/// Calendars settings: the holidays calendar, then every calendar and reminder list,
/// grouped by account, with a switch to show or hide it in the popover.
struct CalendarsSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars

    var body: some View {
        KelloPane(pane: .calendars, subtitle: String(localized: "Choose which calendars and reminder lists appear in the menu bar.")) {
            if calendars.eventsAccess != .granted {
                SettingsGroup {
                    SettingsRow(String(localized: "Allow Kello to access your calendars to choose which ones to show.")) {
                        Button("Open Privacy Settings…") { calendars.openPrivacySettings(for: .event) }
                            .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                    }
                }
            } else {
                SettingsGroup(String(localized: "Holidays"),
                              footer: String(localized: "Days with an event in this calendar get a red number in the grid, and the holiday's name shows above that day's agenda.")) {
                    SettingsRow(String(localized: "Holidays calendar")) { holidayPicker }
                }
            }
            // Calendars and reminder lists can share an account name, so each section is
            // keyed by kind as well.
            ForEach(sections, id: \.id) { section in
                SettingsGroup(section.title) {
                    ForEach(section.calendars) { calendar in
                        CalendarToggle(calendar: calendar)
                    }
                }
            }
        }
    }

    /// Shows the automatic pick until one is chosen; choosing "None" turns holidays off.
    private var holidayPicker: some View {
        let all = calendars.eventCalendars
        let selection = Binding<String>(
            get: { store.settings.holidayCalendar.resolvedID(among: all) ?? "" },
            set: { store.settings.holidayCalendar = $0.isEmpty ? .none : .calendar($0) })
        let current = all.first { $0.id == selection.wrappedValue }
        return PopUpMenu(current.map { Text(verbatim: $0.title) } ?? Text("None")) {
            Picker("Holidays calendar", selection: selection) {
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
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .accessibilityLabel(Text("Holidays calendar"))
    }

    private var sections: [(id: String, title: String, calendars: [CalendarInfo])] {
        CalendarGroup.grouped(calendars.eventCalendars).map { ("e|\($0.id)", $0.sourceTitle, $0.calendars) }
            + CalendarGroup.grouped(calendars.reminderLists).map {
                ("r|\($0.id)", String(localized: "Reminders · \($0.sourceTitle)"), $0.calendars)
            }
    }
}

/// A calendar's color swatch, title and visibility switch, as one row of a group.
struct CalendarToggle: View {
    @Environment(SettingsStore.self) private var store
    let calendar: CalendarInfo

    var body: some View {
        SwitchRow(calendar.title, symbol: "circle.fill", symbolColor: Color(calendar.color), isOn: Binding(
            get: { store.settings.isCalendarVisible(calendar.id) },
            set: { store.settings.setCalendar(calendar.id, visible: $0) }))
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
