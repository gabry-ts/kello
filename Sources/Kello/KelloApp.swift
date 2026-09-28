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
    func applicationDidFinishLaunching(_ notification: Notification) {}
}
