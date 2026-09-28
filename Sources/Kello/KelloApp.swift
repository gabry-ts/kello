import KelloCore
import SwiftUI

@main
struct KelloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// The menu bar item is an NSStatusItem owned by the app delegate; this scene only
    /// satisfies SwiftUI's need for one.
    var body: some Scene {
        SwiftUI.Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController {
            AnyView(MenuContent())
        } render: {
            Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }
}
