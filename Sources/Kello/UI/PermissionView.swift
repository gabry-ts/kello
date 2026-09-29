import EventKit
import SwiftUI

/// Shown in the popover until Kello can read calendars (and has asked about reminders):
/// why it needs access, and a way to grant it, or to fix it in System Settings once denied.
struct PermissionView: View {
    @Environment(CalendarStore.self) private var calendars

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 24, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.accentColor.gradient, in: .rect(cornerRadius: 14, style: .continuous))
                .shadow(color: .accentColor.opacity(0.35), radius: 8, y: 3)
            VStack(spacing: 4) {
                Text("Connect Your Calendars")
                    .font(.system(size: 15, weight: .semibold))
                Text("Kello shows your events and reminders right from the menu bar. Everything stays on this Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            VStack(spacing: 0) {
                row("Calendars", systemImage: "calendar", access: calendars.eventsAccess, type: .event)
                Hairline(leading: 44)
                row("Reminders", systemImage: "checklist", access: calendars.remindersAccess, type: .reminder)
            }
            .surface(radius: Theme.groupRadius)
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, access: CalendarStore.Access, type: EKEntityType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            switch access {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
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
        .padding(.horizontal, 12)
        .frame(height: 44)
        .animation(.snappy, value: access)
    }
}
