import EventKit
import PartitiUI
import SwiftUI

/// Shown in the popover until Kello can read calendars (and has asked about reminders):
/// why it needs access, and a way to grant it, or to fix it in System Settings once denied.
struct PermissionView: View {
    @Environment(CalendarStore.self) private var calendars
    @Environment(\.puiAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let ink = Ink(colorScheme)
        VStack(spacing: PUI.Space.m + 2) {
            IconTile("calendar.badge.clock", color: accent.color, size: PUI.Window.paneTile)
            VStack(spacing: PUI.Space.xs) {
                Text("Connect Your Calendars")
                    .font(PUI.Font.headline)
                    .foregroundStyle(ink.primary)
                Text("Kello shows your events and reminders right from the menu bar. Everything stays on this Mac.")
                    .font(PUI.Font.caption)
                    .foregroundStyle(ink.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, PUI.Space.s)
            VStack(spacing: 0) {
                row("Calendars", systemImage: "calendar", access: calendars.eventsAccess, type: .event, ink)
                Hairline(leading: 38)
                row("Reminders", systemImage: "checklist", access: calendars.remindersAccess, type: .reminder, ink)
            }
            .puiSurface(radius: PUI.Radius.group)
        }
        .padding(.top, PUI.Space.xs)
        .padding(.bottom, PUI.Space.xxs)
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, access: CalendarStore.Access, type: EKEntityType,
                     _ ink: Ink) -> some View {
        HStack(spacing: PUI.Space.m) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accent.legible(colorScheme))
                .frame(width: 20)
            Text(title)
                .font(PUI.Font.callout.weight(.medium))
                .foregroundStyle(ink.primary)
            Spacer()
            switch access {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ink.green)
                    .transition(.scale.combined(with: .opacity))
            case .notDetermined:
                Button("Allow") {
                    Task {
                        if type == .event { await calendars.requestEventsAccess() } else { await calendars.requestRemindersAccess() }
                    }
                }
                .buttonStyle(PrimaryButtonStyle(height: PUI.Control.small, fullWidth: false))
            case .writeOnly, .denied:
                Button("Open Settings") { calendars.openPrivacySettings(for: type) }
                    .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
            }
        }
        .padding(.horizontal, PUI.Space.m + 2)
        .frame(height: 36)
        .animation(.snappy, value: access)
    }
}
