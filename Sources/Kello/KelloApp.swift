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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = SettingsStore()
    private let navigation = Navigation()
    private var window: NSWindow?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.saveNow()

        statusItem = StatusItemController {
            AnyView(MenuContent(openSettings: { [weak self] in
                self?.statusItem?.closePopover()
                self?.openSettingsWindow()
            }))
        } render: {
            Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    /// Reopening the app (Spotlight, Finder) brings settings back, even with the menu bar
    /// icon hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow()
        return true
    }

    func openSettingsWindow() {
        openWindow(.general)
    }

    /// Opens the settings window on `pane`, reusing it if it's already open.
    private func openWindow(_ pane: SettingsView.Pane) {
        NSApp.activate()
        navigation.pane = pane
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsView(navigation: navigation)
            .environment(store)
        let window = makeWindow(view, size: NSSize(width: 640, height: 420), minSize: NSSize(width: 560, height: 360))
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(_ view: some View, size: NSSize, minSize: NSSize) -> NSWindow {
        let controller = NSHostingController(rootView: view)
        controller.sceneBridgingOptions = [.toolbars]
        let window = NSWindow(contentViewController: controller)
        window.title = "Kello"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(size)
        window.minSize = minSize
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        return window
    }

    /// A closed window is torn down rather than kept around.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        window.contentViewController = nil
        if window === self.window { self.window = nil }
    }
}
