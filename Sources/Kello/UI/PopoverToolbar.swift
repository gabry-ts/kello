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
                    .enabledLook(search != nil)
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
                .enabledLook(newEvent != nil || newReminder != nil)
                .help("New")
            }
        }
    }
}

/// The popover footer: Settings…, the ⋯ menu with the agenda options, updates and
/// Buy Me a Coffee…, then Quit. Built from Partiti UI's footer buttons, so every label
/// goes through Kello's own string catalog.
struct KelloFooter: View {
    let openSettings: () -> Void
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars
    @Environment(\.puiGlassRendering) private var rendering

    var body: some View {
        HStack(spacing: 0) {
            FooterButton(String(localized: "Settings…"), symbol: "gearshape", action: openSettings)
                .keyboardShortcut(",", modifiers: .command)
            moreMenu
            Spacer(minLength: 0)
            FooterButton(String(localized: "Quit"), symbol: "power") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, -PUI.Space.xxs)
    }

    /// A real menu when live; its label alone when painted, since menus don't render offscreen.
    @ViewBuilder
    private var moreMenu: some View {
        switch rendering {
        case .live:
            Menu {
                Toggle("Show Upcoming Days", isOn: Binding(
                    get: { store.settings.agendaMode == .upcoming },
                    set: { store.settings.agendaMode = $0 ? .upcoming : .day }))
                if calendars.eventsAccess == .granted {
                    CalendarVisibilityMenu()
                }
                Divider()
                Button("Check for Updates…") { Updater.checkForUpdates() }
                Button("Buy Me a Coffee…") { ExternalLinks.openBuyMeACoffee() }
            } label: {
                FooterMenuLabel(symbol: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        case .painted:
            FooterMenuLabel(symbol: "ellipsis")
        }
    }
}

/// The look of a footer button without a title, for a menu's label.
private struct FooterMenuLabel: View {
    let symbol: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Ink(colorScheme).secondary)
            .padding(.horizontal, PUI.Space.s + 1)
            .frame(height: PUI.Control.small + 2)
            .contentShape(.rect)
    }
}

/// A borderless icon that opens a menu, matching Partiti UI's `IconButton` inside a
/// `GlassCapsule`. Drawn as its label alone when painted.
struct IconMenu<Items: View>: View {
    let symbol: String
    @ViewBuilder let items: () -> Items
    @Environment(\.puiGlassRendering) private var rendering
    @Environment(\.colorScheme) private var colorScheme

    init(_ symbol: String, @ViewBuilder items: @escaping () -> Items) {
        self.symbol = symbol
        self.items = items
    }

    var body: some View {
        switch rendering {
        case .live:
            Menu(content: items) { label }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
        case .painted:
            label
        }
    }

    private var label: some View {
        Image(systemName: symbol)
            .font(.system(size: PUI.Control.smallSymbol, weight: .medium))
            .foregroundStyle(Ink(colorScheme).primary.opacity(0.78))
            .frame(width: 24, height: PUI.Control.small)
            .contentShape(.rect)
    }
}

extension View {
    /// Dims a control that can't be used right now; Partiti UI's icon buttons keep one look.
    func enabledLook(_ isEnabled: Bool) -> some View {
        disabled(!isEnabled).opacity(isEnabled ? 1 : 0.4)
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
