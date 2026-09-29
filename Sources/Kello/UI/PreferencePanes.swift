import KelloCore
import KeyboardShortcuts
import SwiftUI

struct GeneralView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            PaneHeader(pane: .general, subtitle: "How the calendar in the menu bar popover is laid out.")
            Section {
                Picker("First day of the week", selection: $store.settings.firstWeekday) {
                    Text("System Default").tag(FirstWeekday.system)
                    Text("Monday").tag(FirstWeekday.monday)
                    Text("Sunday").tag(FirstWeekday.sunday)
                }
                Toggle("Show week numbers", isOn: $store.settings.showWeekNumbers)
            } header: {
                Text("Calendar")
            }
            Section {
                KeyboardShortcuts.Recorder(for: .togglePopover) {
                    Text("Show or hide Kello")
                }
            } header: {
                Text("Keyboard Shortcut")
            } footer: {
                Text("Opens the calendar from any app.")
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Version", value: AppVersion.string)
            }
        }
        .formStyle(.grouped)
    }
}

/// The version and build shown in General, read from the app's own bundle.
enum AppVersion {
    static var string: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}
