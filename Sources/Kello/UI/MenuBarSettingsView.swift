import KelloCore
import SwiftUI

/// Menu bar settings: toggles for what the title shows, an optional custom pattern that
/// overrides them, and a live preview.
struct MenuBarSettingsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            PaneHeader(pane: .menuBar, subtitle: "What the date and time in the menu bar show.")
            Section {
                preview
            }
            Section {
                Toggle("Weekday", isOn: $store.settings.menuBar.showWeekday)
                Toggle("Date", isOn: $store.settings.menuBar.showDate)
                Toggle("Month name (instead of number)", isOn: $store.settings.menuBar.showMonthName)
                    .disabled(!store.settings.menuBar.showDate)
                Toggle("Year", isOn: $store.settings.menuBar.showYear)
                Toggle("Time", isOn: $store.settings.menuBar.showTime)
                Toggle("24-hour clock", isOn: $store.settings.menuBar.is24Hour)
                    .disabled(!store.settings.menuBar.showTime)
            } header: {
                Text("Shown in the Menu Bar")
            } footer: {
                Text("Ignored while a custom pattern is set below.")
                    .foregroundStyle(.secondary)
            }
            Section {
                TextField("e.g. EEE d MMM HH:mm", text: $store.settings.menuBar.customPattern)
            } header: {
                Text("Custom Pattern")
            } footer: {
                Text("A date formatter template. Leave empty to use the toggles above.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var preview: some View {
        HStack {
            Text("Preview")
            Spacer()
            Text(store.settings.menuBarTitle(now: .now))
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .frame(height: 24)
                .glassEffect(.regular, in: .capsule)
        }
    }
}
