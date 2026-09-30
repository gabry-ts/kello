import KelloCore
import PartitiUI
import SwiftUI

/// Menu bar settings: the title's components in a list the user can drag to reorder and
/// switch on or off, an optional literal pattern that overrides them, the text size, and
/// a live preview.
struct MenuBarSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var store = store
        KelloPane(pane: .menuBar, subtitle: String(localized: "What the date and time in the menu bar show.")) {
            SettingsGroup {
                SettingsRow(String(localized: "Preview")) { preview }
                SettingsRow(String(localized: "Text Size")) {
                    Slider(value: $store.settings.menuBar.textSize, in: MenuBarSettings.textSizeRange, step: 0.5)
                        .frame(width: 160)
                }
            }
            SettingsGroup(String(localized: "Shown in the Menu Bar"),
                          footer: String(localized: "Drag to change the order. Ignored while a custom pattern is set below.")) {
                ReorderableRows($store.settings.menuBar.items, isOn: \.isOn) { item in
                    ReorderableLabel(item.component.title)
                }
                SettingsRow(String(localized: "Month name (instead of number)")) {
                    Toggle(String(localized: "Month name (instead of number)"), isOn: $store.settings.menuBar.showMonthName)
                        .toggleStyle(PUISwitchStyle(showsLabel: false))
                }
                .enabledLook(store.settings.menuBar.isOn(.date))
                SettingsRow(String(localized: "24-hour clock")) {
                    Toggle(String(localized: "24-hour clock"), isOn: $store.settings.menuBar.is24Hour)
                        .toggleStyle(PUISwitchStyle(showsLabel: false))
                }
                .enabledLook(store.settings.menuBar.isOn(.time))
            }
            SettingsGroup(String(localized: "Custom Pattern"),
                          footer: String(localized: "Used exactly as written: EEE weekday, d day, MMM month, yyyy year, HH:mm time. Leave empty to use the list above.")) {
                SettingsRow(String(localized: "Pattern")) {
                    TextField("Pattern", text: $store.settings.menuBar.customPattern, prompt: Text(verbatim: "EEE d MMM HH:mm"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 200)
                }
            }
        }
    }

    /// The title as the status item draws it, at the chosen size.
    private var preview: some View {
        PartitiUI.MenuBarItem(highlighted: true, color: Ink(colorScheme).primary) {
            Text(store.settings.menuBarTitle(now: .now))
                .font(.system(size: store.settings.menuBar.textSize, weight: .medium).monospacedDigit())
        }
    }
}

extension MenuBarComponent {
    var title: LocalizedStringKey {
        switch self {
        case .weekday: "Weekday"
        case .date: "Date"
        case .year: "Year"
        case .time: "Time"
        }
    }
}
