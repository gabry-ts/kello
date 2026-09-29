import KelloCore
import SwiftUI

/// The row of icon buttons under the grid.
struct PopoverToolbar: View {
    @Environment(SettingsStore.self) private var store
    @Environment(PopoverState.self) private var popover
    let openSettings: () -> Void

    var body: some View {
        @Bindable var store = store
        @Bindable var popover = popover
        HStack(spacing: 2) {
            Button { popover.isPinned.toggle() } label: {
                Image(systemName: popover.isPinned ? "pin.fill" : "pin")
            }
            .help(popover.isPinned ? "Unpin" : "Keep Open")
            Spacer()
            Button {
                store.settings.agendaMode = store.settings.agendaMode == .day ? .upcoming : .day
            } label: {
                Image(systemName: store.settings.agendaMode == .day ? "list.bullet" : "list.bullet.indent")
            }
            .help(store.settings.agendaMode == .day ? "Show Upcoming" : "Show Selected Day")
            Menu {
                Button("Settings…", action: openSettings)
                    .keyboardShortcut(",")
                Divider()
                Button("Quit Kello") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .help("More")
        }
        .buttonStyle(.icon)
        // Menu items only answer their shortcuts while the menu is open, so these do it
        // for the popover as a whole.
        .background {
            Button("", action: openSettings).keyboardShortcut(",").hidden()
            Button("") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q").hidden()
        }
    }
}

/// "Overdue: N" and "Today: N", each after small bars in the colors involved.
struct StatusRow: View {
    let status: AgendaStatus
    let showsOverdue: Bool

    var body: some View {
        HStack(spacing: 14) {
            if showsOverdue {
                item(String(localized: "Overdue: \(status.overdueCount)"), colors: [.accentColor])
            }
            item(String(localized: "Today: \(status.todayCount)"), colors: status.todayColors.prefix(6).map(Color.init))
            Spacer()
        }
        .font(.system(size: 11, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
    }

    private func item(_ text: String, colors: [Color]) -> some View {
        HStack(spacing: 5) {
            HStack(spacing: 2) {
                ForEach(Array((colors.isEmpty ? [.secondary.opacity(0.4)] : colors).enumerated()), id: \.offset) { _, color in
                    Capsule().fill(color).frame(width: 3, height: 11)
                }
            }
            Text(text)
        }
    }
}
