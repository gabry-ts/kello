import KelloCore
import KeyboardShortcuts
import PartitiUI
import SwiftUI

struct GeneralView: View {
    @Environment(SettingsStore.self) private var store
    /// On while waiting for approval too, since the user did ask for it.
    @State private var launchAtLogin = LoginItem.status != .disabled
    @State private var loginItemStatus = LoginItem.status

    var body: some View {
        @Bindable var store = store
        KelloPane(pane: .general, subtitle: String(localized: "How the calendar in the menu bar popover is laid out.")) {
            SettingsGroup(String(localized: "Startup")) {
                SettingsRow(String(localized: "Launch at login")) {
                    RowSwitch(String(localized: "Launch at login"), isOn: $launchAtLogin)
                }
                if loginItemStatus == .requiresApproval {
                    SettingsRow(String(localized: "Waiting for your approval in System Settings")) {
                        Button("Open Login Items…") { LoginItem.openSystemSettings() }
                            .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                    }
                }
            }
            .onChange(of: launchAtLogin) { _, enabled in
                enabled ? LoginItem.register() : LoginItem.unregister()
                loginItemStatus = LoginItem.status
            }
            .onAppear { loginItemStatus = LoginItem.status }
            SettingsGroup(String(localized: "Calendar")) {
                SettingsRow(String(localized: "First day of the week")) {
                    Picker("First day of the week", selection: $store.settings.firstWeekday) {
                        Text("System Default").tag(FirstWeekday.system)
                        Text("Monday").tag(FirstWeekday.monday)
                        Text("Sunday").tag(FirstWeekday.sunday)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsRow(String(localized: "Show week numbers")) {
                    RowSwitch(String(localized: "Show week numbers"), isOn: $store.settings.showWeekNumbers)
                }
            }
            SettingsGroup(String(localized: "Keyboard Shortcut"), footer: String(localized: "Opens the calendar from any app.")) {
                SettingsRow(String(localized: "Show or hide Kello")) {
                    KeyboardShortcuts.Recorder(for: .togglePopover)
                }
            }
        }
    }
}

/// The version and build shown in About, read from the app's own bundle.
enum AppVersion {
    static var string: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}
