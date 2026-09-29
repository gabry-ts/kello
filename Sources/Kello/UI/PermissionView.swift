import EventKit
import SwiftUI

/// Shown in the popover until Kello can read calendars (and has asked about reminders):
/// why it needs access, and a way to grant it, or to fix it in System Settings once denied.
struct PermissionView: View {
    @Environment(CalendarStore.self) private var calendars

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.gradient, in: .rect(cornerRadius: 10, style: .continuous))
                .shadow(color: .accentColor.opacity(0.35), radius: 6, y: 2)
            VStack(spacing: 3) {
                Text("Connect Your Calendars")
                    .font(.system(size: 13, weight: .semibold))
                Text("Kello shows your events and reminders right from the menu bar. Everything stays on this Mac.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6)
            VStack(spacing: 0) {
                row("Calendars", systemImage: "calendar", access: calendars.eventsAccess, type: .event)
                Hairline(leading: 38)
                row("Reminders", systemImage: "checklist", access: calendars.remindersAccess, type: .reminder)
            }
            .surface(radius: Theme.groupRadius)
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, access: CalendarStore.Access, type: EKEntityType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            switch access {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
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
        .padding(.horizontal, 10)
        .frame(height: 36)
        .animation(.snappy, value: access)
    }
}
