import KelloCore
import PartitiUI
import SwiftUI

@main
struct KelloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        ResourceBundles.redirectToResources()
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--render-snapshots"), args.indices.contains(i + 1) {
            exit(MainActor.assumeIsolated { Snapshots.render(to: URL(fileURLWithPath: args[i + 1])) })
        }
        if let i = args.firstIndex(of: "--render-icon"), args.indices.contains(i + 1) {
            exit(MainActor.assumeIsolated { Snapshots.renderIconSet(to: URL(fileURLWithPath: args[i + 1])) })
        }
    }

    /// The menu bar item is an NSStatusItem owned by the app delegate; this scene only
    /// satisfies SwiftUI's need for one.
    var body: some Scene {
        SwiftUI.Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = SettingsStore()
    let calendars = CalendarStore()
    private lazy var notifier = MeetingNotifier(store: store, calendars: calendars)
    private let popoverState = PopoverState()
    private let navigation = Navigation()
    private var window: NSWindow?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isFirstLaunch = !SettingsStore.hasSavedSettings
        store.saveNow()
        _ = Updater.controller

        statusItem = StatusItemController(state: popoverState) { [store, calendars, popoverState] in
            AnyView(
                MenuContent(openSettings: { [weak self] in
                    self?.statusItem?.closePopover()
                    self?.openSettingsWindow()
                })
                .environment(store)
                .environment(calendars)
                .environment(popoverState)
            )
        } render: { [store] in
            StatusTitle(text: store.settings.menuBarTitle(now: .now), size: store.settings.menuBar.textSize)
        }

        Hotkey.register { [weak self] in self?.statusItem?.togglePopover() }
        notifier.start { [weak self] day in self?.statusItem?.showPopover(on: day) }

        // A menu bar calendar is only useful when it's always there, so it starts at login
        // unless turned off in General.
        if isFirstLaunch {
            LoginItem.register()
        }

        Task { await calendars.requestAccessIfNeeded() }
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
            .environment(calendars)
            .environment(notifier)
        let window = makeWindow(view, size: PUI.Window.settings, minSize: PUI.Window.settingsMin)
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(_ view: some View, size: NSSize, minSize: NSSize) -> NSWindow {
        let controller = NSHostingController(rootView: view)
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
