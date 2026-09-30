import KelloCore
import PartitiUI
import SwiftUI

/// The row under the grid: the Agenda / Reminders switch, then search, pin and new in
/// one glass capsule.
struct AgendaToolbar: View {
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars
    @Environment(PopoverState.self) private var popover
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
        PopoverToolbar {
            if calendars.remindersAccess == .granted {
                SegmentedPill(
                    [(ListTab.agenda, String(localized: "Agenda")), (ListTab.reminders, String(localized: "Reminders"))],
                    selection: Bindable(store).settings.listTab)
            }
        } trailing: {
            GlassCapsule {
                IconButton("magnifyingglass") { search?() }
                    .disabled(search == nil)
                    .keyboardShortcut("f")
                    .help("Search")
                IconButton(popover.isPinned ? "pin.fill" : "pin", active: popover.isPinned) { popover.isPinned.toggle() }
                    .help(popover.isPinned ? "Unpin" : "Keep Open")
                IconMenu("plus") {
                    Button("New Event") { newEvent?() }
                        .disabled(newEvent == nil)
                    Button("Quick Event…") { quickEvent?() }
                        .disabled(quickEvent == nil)
                    Button("New Reminder") { newReminder?() }
                        .disabled(newReminder == nil)
                }
                .disabled(newEvent == nil && newReminder == nil)
                .help("New")
            }
        }
    }
}

/// Today at a glance: overdue reminders and today's events, each a small chip led by the
/// colors involved.
struct StatusRow: View {
    let status: AgendaStatus
    let showsOverdue: Bool
    @Environment(\.colorScheme) private var colorScheme

    private static let chipHeight: CGFloat = 18

    var body: some View {
        let ink = Ink(colorScheme)
        HStack(spacing: PUI.Space.s) {
            if showsOverdue {
                chip(count: status.overdueCount, label: "overdue", colors: status.overdueCount > 0 ? [ink.red] : [], ink)
            }
            chip(count: status.todayCount, label: "today", colors: status.todayColors.prefix(5).map(Color.init), ink)
            Spacer(minLength: 0)
        }
    }

    private func chip(count: Int, label: LocalizedStringKey, colors: [Color], _ ink: Ink) -> some View {
        HStack(spacing: PUI.Space.xs + 1) {
            HStack(spacing: 1.5) {
                ForEach(Array((colors.isEmpty ? [ink.quaternary] : colors).enumerated()), id: \.offset) { _, color in
                    Capsule().fill(color).frame(width: 2.5, height: 8)
                }
            }
            HStack(spacing: 3) {
                Text("\(count)")
                    .font(PUI.Font.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(ink.primary)
                Text(label)
                    .font(PUI.Font.caption)
                    .foregroundStyle(ink.secondary)
            }
        }
        .padding(.horizontal, PUI.Space.s + 1)
        .frame(height: Self.chipHeight)
        .puiSurface(radius: Self.chipHeight / 2, elevated: false)
    }
}
