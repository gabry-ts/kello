import KelloCore
import PartitiUI
import SwiftUI

/// Popover settings: the popover's sections in a list the user can drag to reorder and
/// switch on or off. The grid, the toolbar and the list are always shown, in their place.
struct PopoverSettingsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        KelloPane(pane: .popover, subtitle: String(localized: "What the calendar popover shows, and in which order.")) {
            ReorderableGroup(String(localized: "Sections"),
                             footer: String(localized: "Drag to reorder. Switch off what you don't need."),
                             items: $store.settings.popover.items,
                             isOn: \.isOn,
                             isLocked: { $0.section.isLocked }) { item in
                ReorderableLabel(item.section.title, subtitle: item.section.subtitle, symbol: item.section.symbol)
            }
        }
    }
}

extension PopoverSection {
    var title: LocalizedStringKey {
        switch self {
        case .grid: "Month grid"
        case .toolbar: "Toolbar"
        case .status: "Today's counts"
        case .clocks: "World clocks"
        case .nextUp: "Next event"
        case .list: "Agenda and reminders"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .grid: "Always at the top."
        case .toolbar: "Agenda or reminders, search, keep open and new. Always under the grid."
        case .status: "Overdue reminders and today's events."
        case .clocks: "Shown once you add time zones."
        case .nextUp: "Today's next event, and how soon it starts."
        case .list: "The day's events or your reminders. Always at the bottom."
        }
    }

    var symbol: String {
        switch self {
        case .grid: "calendar"
        case .toolbar: "switch.2"
        case .status: "number"
        case .clocks: "globe"
        case .nextUp: "clock"
        case .list: "list.bullet"
        }
    }
}
