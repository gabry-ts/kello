import EventKit
import SwiftUI

/// Shown in the popover until Kello can read calendars (and has asked about reminders):
/// why it needs access, and a way to grant it, or to fix it in System Settings once denied.
struct PermissionView: View {
    @Environment(CalendarStore.self) private var calendars

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 30, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(spacing: 4) {
                Text("Connect Your Calendars")
                    .font(.headline)
                Text("Kello shows your events and reminders right from the menu bar. Everything stays on this Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                row("Calendars", systemImage: "calendar", access: calendars.eventsAccess, type: .event)
                Divider().padding(.leading, 32)
                row("Reminders", systemImage: "checklist", access: calendars.remindersAccess, type: .reminder)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(.primary.opacity(0.04), in: .rect(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, access: CalendarStore.Access, type: EKEntityType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
            Spacer()
            switch access {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            case .notDetermined:
                Button("Allow") {
                    Task {
                        if type == .event { await calendars.requestEventsAccess() } else { await calendars.requestRemindersAccess() }
                    }
                }
                .buttonStyle(.glassProminent)
            case .writeOnly, .denied:
                Button("Open Settings") { calendars.openPrivacySettings(for: type) }
                    .buttonStyle(.glass)
            }
        }
        .controlSize(.small)
        .frame(height: 36)
        .animation(.snappy, value: access)
    }
}
