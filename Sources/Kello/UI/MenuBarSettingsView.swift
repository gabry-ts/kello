import KelloCore
import SwiftUI

/// Menu bar settings: the title's components in a list the user can drag to reorder and
/// switch on or off, an optional literal pattern that overrides them, the text size, and
/// a live preview.
struct MenuBarSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var dropTarget: MenuBarComponent?

    var body: some View {
        @Bindable var store = store
        Form {
            PaneHeader(pane: .menuBar, subtitle: "What the date and time in the menu bar show.")
            Section {
                preview
                LabeledContent("Text Size") {
                    Slider(value: $store.settings.menuBar.textSize, in: MenuBarSettings.textSizeRange, step: 0.5)
                        .frame(width: 160)
                }
            }
            Section {
                ForEach(store.settings.menuBar.items) { item in
                    row(item)
                }
                Toggle("Month name (instead of number)", isOn: $store.settings.menuBar.showMonthName)
                    .disabled(!store.settings.menuBar.isOn(.date))
                Toggle("24-hour clock", isOn: $store.settings.menuBar.is24Hour)
                    .disabled(!store.settings.menuBar.isOn(.time))
            } header: {
                Text("Shown in the Menu Bar")
            } footer: {
                Text("Drag to change the order. Ignored while a custom pattern is set below.")
                    .foregroundStyle(.secondary)
            }
            Section {
                TextField("Pattern", text: $store.settings.menuBar.customPattern, prompt: Text(verbatim: "EEE d MMM HH:mm"))
                    .labelsHidden()
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("Custom Pattern")
            } footer: {
                Text("Used exactly as written: EEE weekday, d day, MMM month, yyyy year, HH:mm time. Leave empty to use the list above.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ item: MenuBarItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
            Toggle(item.component.title, isOn: Binding(
                get: { store.settings.menuBar.isOn(item.component) },
                set: { store.settings.menuBar.set(item.component, isOn: $0) }))
        }
        .contentShape(Rectangle())
        .background {
            // The row the dragged component will take the place of.
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(dropTarget == item.component ? 0.15 : 0))
                .padding(-4)
        }
        .draggable(item.component.rawValue) {
            Text(item.component.title).padding(6)
        }
        .dropDestination(for: String.self) { values, _ in
            guard let raw = values.first, let moved = MenuBarComponent(rawValue: raw) else { return false }
            move(moved, onto: item.component)
            return true
        } isTargeted: { targeted in
            if targeted { dropTarget = item.component } else if dropTarget == item.component { dropTarget = nil }
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

    private var preview: some View {
        HStack {
            Text("Preview")
            Spacer()
            Text(store.settings.menuBarTitle(now: .now))
                .font(.system(size: store.settings.menuBar.textSize, weight: .medium))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .frame(height: 24)
                .glassEffect(.regular, in: .capsule)
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
