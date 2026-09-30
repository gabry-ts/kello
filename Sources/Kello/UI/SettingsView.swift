import Observation
import PartitiUI
import SwiftUI

/// Which page the settings window shows, so the popover can open it on a given page.
@MainActor
@Observable
final class Navigation {
    var pane: SettingsView.Pane

    init(pane: SettingsView.Pane = .general) {
        self.pane = pane
    }
}

/// The settings window: Partiti UI's floating sidebar, one pane per section.
struct SettingsView: View {
    @Bindable var navigation: Navigation

    enum Pane: String, CaseIterable, Hashable {
        case general
        case calendars
        case notifications
        case menuBar
        case popover
        case timeZones
        case about

        var title: String {
            switch self {
            case .general: String(localized: "General")
            case .calendars: String(localized: "Calendars")
            case .notifications: String(localized: "Notifications")
            case .menuBar: String(localized: "Menu Bar")
            case .popover: String(localized: "Popover")
            case .timeZones: String(localized: "Time Zones")
            case .about: String(localized: "About")
            }
        }

        var icon: String {
            switch self {
            case .general: "gearshape.fill"
            case .calendars: "calendar"
            case .notifications: "bell.badge.fill"
            case .menuBar: "menubar.rectangle"
            case .popover: "list.bullet.below.rectangle"
            case .timeZones: "globe"
            case .about: "info"
            }
        }

        /// The tile color behind the icon, as in System Settings.
        var tint: Color {
            switch self {
            case .general: .gray
            case .calendars: .red
            case .notifications: .orange
            case .menuBar: .blue
            case .popover: .purple
            case .timeZones: .indigo
            case .about: .teal
            }
        }
    }

    var body: some View {
        SettingsWindow(sections: [SidebarSection(nil, Pane.allCases.map {
            SidebarItem(Text(verbatim: $0.title), id: $0.rawValue, symbol: $0.icon, style: .tile($0.tint))
        })], selection: selection) {
            paneView(navigation.pane)
        }
        .frame(minWidth: PUI.Window.settingsMin.width, minHeight: PUI.Window.settingsMin.height)
        .puiAccent(.kello)
    }

    /// The sidebar selects by the pane's stable raw value, so it doesn't change with the
    /// language, as its localized title would.
    private var selection: Binding<String> {
        Binding(
            get: { navigation.pane.rawValue },
            set: { id in
                if let pane = Pane.allCases.first(where: { $0.rawValue == id }) { navigation.pane = pane }
            })
    }

    @ViewBuilder
    private func paneView(_ pane: Pane) -> some View {
        switch pane {
        case .general: GeneralView()
        case .calendars: CalendarsSettingsView()
        case .notifications: NotificationsSettingsView()
        case .menuBar: MenuBarSettingsView()
        case .popover: PopoverSettingsView()
        case .timeZones: TimeZonesSettingsView()
        case .about: AboutView()
        }
    }
}

/// A scrolling settings pane opening with Partiti UI's header for `pane`.
struct KelloPane<Content: View>: View {
    let pane: SettingsView.Pane
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            SettingsPane {
                PaneHeader(pane.title, subtitle: subtitle, symbol: pane.icon, color: pane.tint)
            } content: {
                content
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
