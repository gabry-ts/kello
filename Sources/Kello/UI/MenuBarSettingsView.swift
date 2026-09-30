import KelloCore
import PartitiUI
import SwiftUI

/// Menu bar settings: the title's components in a list the user can drag to reorder and
/// switch on or off, an optional literal pattern that overrides them, the text size, and
/// a live preview.
struct MenuBarSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.puiAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @State private var dropTarget: MenuBarComponent?

    var body: some View {
        @Bindable var store = store
        KelloPane(pane: .menuBar, subtitle: String(localized: "What the date and time in the menu bar show.")) {
            SettingsGroup {
                SettingsRow(String(localized: "Preview")) { preview }
                SettingsRow(String(localized: "Text Size")) {
                    Slider(value: $store.settings.menuBar.textSize, in: MenuBarSettings.textSizeRange, step: 0.5)
                        .frame(width: 160)
                }
            }
            SettingsGroup(String(localized: "Shown in the Menu Bar"),
                          footer: String(localized: "Drag to change the order. Ignored while a custom pattern is set below.")) {
                ForEach(store.settings.menuBar.items) { item in
                    row(item.component)
                }
                SettingsRow(String(localized: "Month name (instead of number)")) {
                    Toggle(String(localized: "Month name (instead of number)"), isOn: $store.settings.menuBar.showMonthName)
                        .toggleStyle(PUISwitchStyle(showsLabel: false))
                }
                .enabledLook(store.settings.menuBar.isOn(.date))
                SettingsRow(String(localized: "24-hour clock")) {
                    Toggle(String(localized: "24-hour clock"), isOn: $store.settings.menuBar.is24Hour)
                        .toggleStyle(PUISwitchStyle(showsLabel: false))
                }
                .enabledLook(store.settings.menuBar.isOn(.time))
            }
            SettingsGroup(String(localized: "Custom Pattern"),
                          footer: String(localized: "Used exactly as written: EEE weekday, d day, MMM month, yyyy year, HH:mm time. Leave empty to use the list above.")) {
                SettingsRow(String(localized: "Pattern")) {
                    TextField("Pattern", text: $store.settings.menuBar.customPattern, prompt: Text(verbatim: "EEE d MMM HH:mm"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 200)
                }
            }
        }
    }

    private func row(_ component: MenuBarComponent) -> some View {
        let ink = Ink(colorScheme)
        return HStack(spacing: PUI.Space.m) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(ink.tertiary)
            Text(component.title)
                .font(PUI.Font.body)
                .foregroundStyle(ink.primary)
            Spacer(minLength: PUI.Space.l)
            Toggle(isOn: Binding(
                get: { store.settings.menuBar.isOn(component) },
                set: { store.settings.menuBar.set(component, isOn: $0) })) { EmptyView() }
                .toggleStyle(PUISwitchStyle())
                .accessibilityLabel(Text(component.title))
        }
        .padding(.horizontal, PUI.Space.l)
        .frame(minHeight: 38)
        .contentShape(Rectangle())
        .background {
            // The row the dragged component will take the place of.
            RoundedRectangle(cornerRadius: PUI.Radius.row, style: .continuous)
                .fill(accent.color.opacity(dropTarget == component ? 0.15 : 0))
                .padding(PUI.Space.xxs)
        }
        .draggable(component.rawValue) {
            Text(component.title).padding(PUI.Space.s)
        }
        .dropDestination(for: String.self) { values, _ in
            guard let raw = values.first, let moved = MenuBarComponent(rawValue: raw) else { return false }
            move(moved, onto: component)
            return true
        } isTargeted: { targeted in
            if targeted { dropTarget = component } else if dropTarget == component { dropTarget = nil }
        }
    }

    /// Moves `component` into `target`'s slot: dragged up it lands before the target,
    /// dragged down after it, so the first and last slots are both reachable.
    private func move(_ component: MenuBarComponent, onto target: MenuBarComponent) {
        var items = store.settings.menuBar.items
        guard component != target,
              let from = items.firstIndex(where: { $0.component == component }),
              let to = items.firstIndex(where: { $0.component == target }) else { return }
        items.move(fromOffsets: IndexSet(integer: from), toOffset: from < to ? to + 1 : to)
        store.settings.menuBar.items = items
    }

    /// The title as the status item draws it, at the chosen size.
    private var preview: some View {
        PartitiUI.MenuBarItem(highlighted: true, color: Ink(colorScheme).primary) {
            Text(store.settings.menuBarTitle(now: .now))
                .font(.system(size: store.settings.menuBar.textSize, weight: .medium).monospacedDigit())
        }
    }
}

extension MenuBarComponent {
    var title: LocalizedStringKey {
        switch self {
        case .weekday: "Weekday"
        case .date: "Date"
        case .year: "Year"
        case .time: "Time"
        }
    }
}
