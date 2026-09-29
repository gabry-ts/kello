import KelloCore
import SwiftUI

/// The row under the grid: the Agenda / Reminders switch, then search, pin, new and more
/// in one glass capsule, like the month header's Today pill.
struct PopoverToolbar: View {
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars
    @Environment(PopoverState.self) private var popover
    let openSettings: () -> Void
    /// Nil while calendars can't be read.
    var search: (() -> Void)?
    /// Nil while calendars can't be read.
    var newEvent: (() -> Void)?
    /// Nil while calendars can't be read.
    var quickEvent: (() -> Void)?
    /// Nil while reminders can't be read.
    var newReminder: (() -> Void)?

    var body: some View {
        @Bindable var popover = popover
        HStack(spacing: 8) {
            if calendars.remindersAccess == .granted {
                TabSwitch(selection: Bindable(store).settings.listTab)
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Button { search?() } label: {
                    ToolbarIcon(systemImage: "magnifyingglass")
                }
                .disabled(search == nil)
                .keyboardShortcut("f")
                .help("Search")
                Button { popover.isPinned.toggle() } label: {
                    ToolbarIcon(systemImage: popover.isPinned ? "pin.fill" : "pin", isActive: popover.isPinned)
                }
                .help(popover.isPinned ? "Unpin" : "Keep Open")
                Menu {
                    Button("New Event") { newEvent?() }
                        .disabled(newEvent == nil)
                    Button("Quick Event…") { quickEvent?() }
                        .disabled(quickEvent == nil)
                    Button("New Reminder") { newReminder?() }
                        .disabled(newReminder == nil)
                } label: {
                    ToolbarIcon(systemImage: "plus")
                }
                .disabled(newEvent == nil && newReminder == nil)
                .help("New")
                Menu {
                    Toggle("Show Upcoming Days", isOn: Binding(
                        get: { store.settings.agendaMode == .upcoming },
                        set: { store.settings.agendaMode = $0 ? .upcoming : .day }))
                    if calendars.eventsAccess == .granted {
                        CalendarVisibilityMenu()
                    }
                    Divider()
                    Button("Settings…", action: openSettings)
                        .keyboardShortcut(",")
                    Button("Buy Me a Coffee…") { ExternalLinks.openBuyMeACoffee() }
                    Button("Quit Kello") { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                } label: {
                    ToolbarIcon(systemImage: "ellipsis")
                }
                .help("More")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.icon)
            .padding(1)
            .glassEffect(.regular, in: .capsule)
            .glassEdge(Capsule())
        }
        .frame(height: Theme.controlSize + 4)
        // Menu items only answer their shortcuts while the menu is open, so these do it
        // for the popover as a whole.
        .background {
            Button("", action: openSettings).keyboardShortcut(",").hidden()
            Button("") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q").hidden()
        }
    }
}

/// One symbol in the toolbar's capsule, in the accent color while its toggle is on.
private struct ToolbarIcon: View {
    let systemImage: String
    var isActive = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary.opacity(isEnabled ? 0.8 : 0.3)))
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 30, height: 28)
            .contentShape(.capsule)
    }
}

/// The Agenda / Reminders switch: a glass capsule with the selected segment raised.
private struct TabSwitch: View {
    @Binding var selection: ListTab
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            segment("Agenda", tab: .agenda)
            segment("Reminders", tab: .reminders)
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
        .glassEdge(Capsule())
    }

    private func segment(_ title: LocalizedStringKey, tab: ListTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(Theme.spring(reduceMotion)) { selection = tab }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .fixedSize()
                .padding(.horizontal, 12)
                .frame(height: Theme.segmentHeight)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.16) : Color.white)
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.10), radius: 3, y: 1)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Today at a glance: overdue reminders and today's events, each a small chip led by the
/// colors involved.
struct StatusRow: View {
    let status: AgendaStatus
    let showsOverdue: Bool

    var body: some View {
        HStack(spacing: 6) {
            if showsOverdue {
                chip(count: status.overdueCount, label: "overdue", colors: status.overdueCount > 0 ? [.red] : [])
            }
            chip(count: status.todayCount, label: "today", colors: status.todayColors.prefix(5).map(Color.init))
            Spacer(minLength: 0)
        }
    }

    private func chip(count: Int, label: LocalizedStringKey, colors: [Color]) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(Array((colors.isEmpty ? [.secondary.opacity(0.35)] : colors).enumerated()), id: \.offset) { _, color in
                    Capsule().fill(color).frame(width: 3, height: 10)
                }
            }
            HStack(spacing: 3) {
                Text("\(count)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 22)
        .surface(radius: 11, elevated: false)
    }
}
