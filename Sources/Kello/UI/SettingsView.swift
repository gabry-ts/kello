import Observation
import SwiftUI

/// Which page the settings window shows, so the popover can open it on a given page.
@MainActor
@Observable
final class Navigation {
    var pane: SettingsView.Pane?

    init(pane: SettingsView.Pane = .general) {
        self.pane = pane
    }
}

/// The settings window: one sidebar, one pane per section.
struct SettingsView: View {
    @Bindable var navigation: Navigation

    enum Pane: String, CaseIterable, Hashable {
        case general
        case calendars
        case notifications
        case menuBar
        case timeZones
        case about

        var title: String {
            switch self {
            case .general: "General"
            case .calendars: "Calendars"
            case .notifications: "Notifications"
            case .menuBar: "Menu Bar"
            case .timeZones: "Time Zones"
            case .about: "About"
            }
        }

        var icon: String {
            switch self {
            case .general: "gearshape.fill"
            case .calendars: "calendar"
            case .notifications: "bell.badge.fill"
            case .menuBar: "menubar.rectangle"
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
            case .timeZones: .indigo
            case .about: .teal
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.pane) {
                ForEach(Pane.allCases, id: \.self, content: paneRow)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detail
        }
        .frame(minWidth: 640, minHeight: 420)
    }

    private func paneRow(_ pane: Pane) -> some View {
        Label {
            Text(pane.title)
        } icon: {
            IconTile(systemImage: pane.icon, tint: pane.tint, size: 22)
        }
        .tag(pane)
    }

    @ViewBuilder
    private var detail: some View {
        if let pane = navigation.pane {
            paneView(pane)
                .navigationTitle(pane.title)
        } else {
            ContentUnavailableView("Select a Section", systemImage: "sidebar.left")
        }
    }

    @ViewBuilder
    private func paneView(_ pane: Pane) -> some View {
        switch pane {
        case .general: GeneralView()
        case .calendars: CalendarsSettingsView()
        case .notifications: NotificationsSettingsView()
        case .menuBar: MenuBarSettingsView()
        case .timeZones: TimeZonesSettingsView()
        case .about: AboutView()
        }
    }
}

/// A white SF Symbol on a rounded, gently shaded color tile.
struct IconTile: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: .rect(cornerRadius: size * 0.27, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
    }
}

/// The top of each settings pane: its icon tile, title and a line about it.
struct PaneHeader: View {
    let pane: SettingsView.Pane
    let subtitle: LocalizedStringKey

    var body: some View {
        Section {
            HStack(spacing: 12) {
                IconTile(systemImage: pane.icon, tint: pane.tint, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pane.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
