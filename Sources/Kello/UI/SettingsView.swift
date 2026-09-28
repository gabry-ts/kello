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

        var title: String {
            switch self {
            case .general: "General"
            }
        }

        var icon: String {
            switch self {
            case .general: "gearshape"
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
        Label(pane.title, systemImage: pane.icon)
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
        }
    }
}
