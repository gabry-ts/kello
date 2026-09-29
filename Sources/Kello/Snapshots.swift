import AppKit
import KelloCore
import SwiftUI

/// `Kello --render-snapshots <dir>` renders the popover with sample data, in light and
/// dark mode, for review. `Kello --render-icon <dir>` writes AppIcon.iconset, which
/// `scripts/make-icon.sh` then turns into AppIcon.icns with `iconutil`. Neither reads
/// the real calendars nor touches the real settings.json.
@MainActor
enum Snapshots {
    static func render(to dir: URL) -> Int32 {
        setvbuf(stdout, nil, _IONBF, 0)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let store = SettingsStore(settings: Settings())
        var weekNumbers = Settings()
        weekNumbers.showWeekNumbers = true
        let weekNumbersStore = SettingsStore(settings: weekNumbers)

        let calendars = CalendarStore(eventsAccess: .granted, remindersAccess: .granted,
                                      events: SampleData.events(now: .now), calendars: SampleData.calendars)
        let unasked = CalendarStore(eventsAccess: .notDetermined, remindersAccess: .notDetermined)
        let denied = CalendarStore(eventsAccess: .granted, remindersAccess: .denied)
        let deniedEvents = CalendarStore(eventsAccess: .denied, remindersAccess: .notDetermined)

        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            snapPopover(popover(store, calendars), name: "popover-\(suffix)", dark: dark, dir: dir)
            snapPopover(popover(store, unasked), name: "permission-\(suffix)", dark: dark, dir: dir)
        }
        snapPopover(popover(store, deniedEvents), name: "permission-denied-light", dark: false, dir: dir)
        snapPopover(popover(weekNumbersStore, denied), name: "popover-weeknumbers-light", dark: false, dir: dir)
        var hidden = Settings()
        hidden.hiddenCalendarIDs = ["work"]
        snapPopover(popover(SettingsStore(settings: hidden), calendars), name: "popover-hidden-work-light", dark: false, dir: dir)
        snapWindow(SettingsView(navigation: Navigation(pane: .calendars)).environment(SettingsStore(settings: hidden)).environment(calendars),
                   name: "settings-calendars-light", dark: false, dir: dir)
        print("Snapshots written to \(dir.path)")
        return 0
    }

    private static func popover(_ store: SettingsStore, _ calendars: CalendarStore) -> some View {
        MenuContent(openSettings: {})
            .environment(store)
            .environment(calendars)
            .environment(PopoverState())
    }

    // MARK: Icon

    static func renderIconSet(to dir: URL) -> Int32 {
        let iconset = dir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            writePNG(renderIcon(size: CGFloat(base)), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
            writePNG(renderIcon(size: CGFloat(base * 2)), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
        }
        print("Wrote \(iconset.path)")
        return 0
    }

    private static func renderIcon(size: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: AppIconView().frame(width: size, height: size))
        renderer.scale = 1
        return renderer.cgImage
    }

    private static func writePNG(_ image: CGImage?, to url: URL) {
        guard let image, let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }

    // MARK: Rendering

    /// Renders the view like the popover: on the window background, rounded, over a plain
    /// desktop-like backdrop. A real offscreen NSPopover can't be used because its glass
    /// samples what's behind it, which offscreen is nothing.
    private static func snapPopover(_ view: some View, name: String, dark: Bool, dir: URL) {
        let framed = view
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .padding(24)
            .background(dark ? Color(red: 0.12, green: 0.14, blue: 0.2) : Color(red: 0.78, green: 0.84, blue: 0.92))
        let controller = NSHostingController(rootView: framed)
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.borderless]
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.setContentSize(controller.view.fittingSize)
        // Off the visible displays, so nothing flashes on screen; the window server can
        // still composite and capture a window regardless of where it's positioned.
        window.setFrameOrigin(NSPoint(x: -6000, y: -6000))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        if let image = windowImage(window), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent("\(name).png"))
            print("  \(name).png")
        }
        window.orderOut(nil)
        window.close()
    }

    private static func snapWindow(_ view: some View, name: String, dark: Bool, dir: URL) {
        let controller = NSHostingController(rootView: view)
        controller.sceneBridgingOptions = [.toolbars]
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.setContentSize(NSSize(width: 640, height: 460))
        window.setFrameOrigin(NSPoint(x: -6000, y: -6000))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        if let image = windowImage(window), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent("\(name).png"))
            print("  \(name).png")
        }
        window.orderOut(nil)
        window.close()
    }

    /// Captures one of our own windows through the window server, so AppKit-backed
    /// SwiftUI controls render exactly as on screen. Looked up at runtime because the
    /// symbol is no longer exposed in the SDK; capturing your own windows needs no permission.
    private static func windowImage(_ window: NSWindow) -> CGImage? {
        typealias Fn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY),
              let sym = dlsym(handle, "CGWindowListCreateImage") else { return nil }
        let fn = unsafeBitCast(sym, to: Fn.self)
        // kCGWindowListOptionIncludingWindow = 8, boundsIgnoreFraming = 1, bestResolution = 8
        return fn(.null, 8, UInt32(window.windowNumber), 1 | 8)?.takeRetainedValue()
    }
}

/// A plausible week of events around today, for snapshots only.
private enum SampleData {
    static let calendars = [
        CalendarInfo(id: "work", title: "Work", sourceTitle: "iCloud", color: ItemColor(red: 0.2, green: 0.5, blue: 1), isWritable: true),
        CalendarInfo(id: "home", title: "Home", sourceTitle: "iCloud", color: ItemColor(red: 0.95, green: 0.35, blue: 0.3), isWritable: true),
        CalendarInfo(id: "gym", title: "Training", sourceTitle: "Google", color: ItemColor(red: 0.2, green: 0.75, blue: 0.4), isWritable: true),
        CalendarInfo(id: "holidays", title: "Holidays", sourceTitle: "Other", color: ItemColor(red: 0.6, green: 0.4, blue: 0.9), isWritable: false),
    ]

    static func events(now: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(byAdding: DateComponents(day: day, hour: hour, minute: minute), to: today)!
        }
        func color(_ id: String) -> ItemColor { calendars.first { $0.id == id }!.color }
        func event(_ title: String, _ calendarID: String, _ start: Date, _ end: Date, allDay: Bool = false, location: String? = nil,
                   url: URL? = nil, recurring: Bool = false, declined: Bool = false) -> CalendarEvent {
            CalendarEvent(eventIdentifier: "\(title)\(start)", calendarID: calendarID, title: title, start: start, end: end, isAllDay: allDay,
                          location: location, url: url, isRecurring: recurring, isDeclined: declined, color: color(calendarID),
                          meetingURL: MeetingLink.find(in: [url?.absoluteString, location]))
        }
        var events = [
            event("Design review", "work", at(0, 9), at(0, 9, 30), location: "https://meet.google.com/abc-defg-hij", recurring: true),
            event("Lunch with Sara", "home", at(0, 12, 30), at(0, 13, 30), location: "Trattoria da Mario"),
            event("Quarterly planning", "work", at(0, 15), at(0, 16), url: URL(string: "https://example.com/plan")),
            event("Old sync", "work", at(0, 17), at(0, 17, 30), declined: true),
            event("Running", "gym", at(0, 19), at(0, 20), recurring: true),
            event("Company offsite", "work", at(1, 0), at(3, 0), allDay: true),
            event("Dentist", "home", at(2, 10), at(2, 11)),
        ]
        for offset in [-9, -6, -2, 4, 8, 11, 15, 18] {
            events.append(event("Standup", "work", at(offset, 9), at(offset, 9, 15), recurring: true))
        }
        for offset in [-5, 5, 12] {
            events.append(event("Holiday", "holidays", at(offset, 0), at(offset + 1, 0), allDay: true))
        }
        return events
    }
}
