import KelloCore
import PartitiUI
import SwiftUI

/// Notifications settings: whether to be told before meetings, how early, and for which
/// events, with a way back to System Settings when notifications are turned off.
struct NotificationsSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(MeetingNotifier.self) private var notifier

    var body: some View {
        @Bindable var store = store
        let alerts = store.settings.meetingAlerts
        KelloPane(pane: .notifications, subtitle: String(localized: "A heads-up shortly before your meetings start.")) {
            SettingsGroup(String(localized: "Meetings"),
                          footer: String(localized: "For events in the calendars Kello shows. Click a notification to open that day, or Join to open the call.")) {
                SwitchRow(String(localized: "Notify before meetings"), isOn: Binding(
                    get: { alerts.isEnabled },
                    set: { enabled in
                        store.settings.meetingAlerts.isEnabled = enabled
                        if enabled { Task { await notifier.requestAuthorization() } }
                    }))
                SettingsRow(String(localized: "Notify me")) {
                    PopUpMenu(selection: $store.settings.meetingAlerts.minutesBefore,
                              options: MeetingAlertSettings.leadTimes.map { ($0, Text("\($0) minutes before")) })
                        .accessibilityLabel(Text("Notify me"))
                }
                .disabled(!alerts.isEnabled)
                SwitchRow(String(localized: "Only events with a call link"), isOn: $store.settings.meetingAlerts.onlyWithMeetingLink)
                    .disabled(!alerts.isEnabled)
            }
            if alerts.isEnabled && notifier.authorization == .denied {
                SettingsGroup {
                    SettingsRow(String(localized: "Notifications are turned off for Kello")) {
                        Button("Open System Settings…") { notifier.openSystemSettings() }
                            .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                    }
                }
            }
        }
        .task { await notifier.refreshAuthorization() }
    }
}
