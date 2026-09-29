import KelloCore
import SwiftUI

/// Notifications settings: whether to be told before meetings, how early, and for which
/// events, with a way back to System Settings when notifications are turned off.
struct NotificationsSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(MeetingNotifier.self) private var notifier

    var body: some View {
        @Bindable var store = store
        let alerts = store.settings.meetingAlerts
        Form {
            PaneHeader(pane: .notifications, subtitle: "A heads-up shortly before your meetings start.")
            Section {
                Toggle("Notify before meetings", isOn: Binding(
                    get: { alerts.isEnabled },
                    set: { enabled in
                        store.settings.meetingAlerts.isEnabled = enabled
                        if enabled { Task { await notifier.requestAuthorization() } }
                    }))
                Picker("Notify me", selection: $store.settings.meetingAlerts.minutesBefore) {
                    ForEach(MeetingAlertSettings.leadTimes, id: \.self) { minutes in
                        Text("\(minutes) minutes before").tag(minutes)
                    }
                }
                .disabled(!alerts.isEnabled)
                Toggle("Only events with a call link", isOn: $store.settings.meetingAlerts.onlyWithMeetingLink)
                    .disabled(!alerts.isEnabled)
            } header: {
                Text("Meetings")
            } footer: {
                Text("For events in the calendars Kello shows. Click a notification to open that day, or Join to open the call.")
                    .foregroundStyle(.secondary)
            }
            if alerts.isEnabled && notifier.authorization == .denied {
                Section {
                    LabeledContent {
                        Button("Open System Settings…") { notifier.openSystemSettings() }
                    } label: {
                        Label("Notifications are turned off for Kello", systemImage: "bell.slash")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { await notifier.refreshAuthorization() }
    }
}
