import KelloCore
import SwiftUI

/// Calendars settings: every calendar, grouped by account, with a toggle to show or hide
/// it in the popover.
struct CalendarsSettingsView: View {
    @Environment(CalendarStore.self) private var calendars

    var body: some View {
        Form {
            if calendars.eventsAccess != .granted {
                Section {
                    Text("Allow Kello to access your calendars to choose which ones to show.")
                        .foregroundStyle(.secondary)
                    Button("Open Privacy Settings…") { calendars.openPrivacySettings(for: .event) }
                }
            }
            ForEach(CalendarGroup.grouped(calendars.eventCalendars)) { group in
                Section(group.sourceTitle) {
                    ForEach(group.calendars) { calendar in
                        CalendarToggle(calendar: calendar)
                    }
                }
            }
        }
        .formStyle(.grouped)
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
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(calendar.color))
                    .frame(width: 10, height: 10)
                Text(calendar.title)
            }
        }
    }
}

/// The toolbar's quick picker: the same toggles, as a menu grouped by account.
struct CalendarVisibilityMenu: View {
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars

    var body: some View {
        Menu {
            ForEach(CalendarGroup.grouped(calendars.eventCalendars)) { group in
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
        } label: {
            Image(systemName: "calendar.badge.checkmark")
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .help("Calendars")
    }
}
