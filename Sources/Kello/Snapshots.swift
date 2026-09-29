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
                                      events: SampleData.events(now: SampleData.now), calendars: SampleData.calendars,
                                      reminders: SampleData.reminders(now: SampleData.now), reminderLists: SampleData.lists)
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
        hidden.timeZones = SampleData.timeZones
        hidden.menuBarTimeZone = SampleData.timeZones[0].identifier
        hidden.meetingAlerts.isEnabled = true
        snapPopover(popover(SettingsStore(settings: hidden), calendars), name: "popover-hidden-work-light", dark: false, dir: dir)
        for dark in [false, true] {
            for pane in SettingsView.Pane.allCases {
                snapWindow(SettingsView(navigation: Navigation(pane: pane)).environment(SettingsStore(settings: hidden)).environment(calendars)
                               .environment(MeetingNotifier(authorization: .authorized)),
                           name: "settings-\(pane.rawValue)-\(dark ? "dark" : "light")", dark: dark, dir: dir)
            }
        }
        let sampleEvent = SampleData.events(now: SampleData.now)[0]
        snapPopover(EventEditorView(draft: EventDraft(sample: sampleEvent), onClose: {}).popoverFrame()
                        .environment(calendars), name: "editor-light", dark: false, dir: dir)
        for dark in [false, true] {
            snapPopover(EventEditorView(draft: .new(on: .now, now: .now, calendarID: "work"), onClose: {}).popoverFrame()
                            .environment(calendars), name: "editor-new-\(dark ? "dark" : "light")", dark: dark, dir: dir)
        }
        snapPopover(QuickEntryView(onClose: {}, onEditDetails: { _ in }, calendarID: "home").popoverFrame()
                        .environment(calendars), name: "quick-entry-empty-light", dark: false, dir: dir)
        var remindersTab = Settings()
        remindersTab.listTab = .reminders
        snapPopover(popover(SettingsStore(settings: remindersTab), calendars), name: "popover-reminders-light", dark: false, dir: dir)
        snapPopover(ReminderEditorView(draft: ReminderDraft(SampleData.reminders(now: .now)[0]), onClose: {}).popoverFrame()
                        .environment(calendars), name: "reminder-editor-light", dark: false, dir: dir)
        snapPopover(popover(SettingsStore(settings: remindersTab), calendars), name: "popover-reminders-dark", dark: true, dir: dir)
        snapPopover(EventEditorView(draft: EventDraft(sample: sampleEvent), onClose: {}).popoverFrame()
                        .environment(calendars), name: "editor-dark", dark: true, dir: dir)
        var clocks = Settings()
        clocks.timeZones = SampleData.timeZones
        for dark in [false, true] {
            snapPopover(popover(SettingsStore(settings: clocks), calendars), name: "popover-clocks-\(dark ? "dark" : "light")", dark: dark, dir: dir)
        }
        snapWindow(TimeZonePicker(excluded: [], onPick: { _ in }), name: "time-zone-picker-light", dark: false, dir: dir,
                   size: NSSize(width: 420, height: 440))
        for dark in [false, true] {
            snapPopover(QuickEntryView(onClose: {}, onEditDetails: { _ in }, text: "Call Marco friday 10:00-11:00", calendarID: "work")
                            .popoverFrame().environment(calendars),
                        name: "quick-entry-\(dark ? "dark" : "light")", dark: dark, dir: dir)
            snapPopover(callRows, name: "event-rows-calls-\(dark ? "dark" : "light")", dark: dark, dir: dir)
            snapPopover(SearchView(now: SampleData.now, onClose: {}, onSelect: { _ in }, initialQuery: "stand")
                            .popoverFrame().environment(store).environment(calendars),
                        name: "search-\(dark ? "dark" : "light")", dark: dark, dir: dir)
        }
        print("Snapshots written to \(dir.path)")
        return 0
    }

    private static func popover(_ store: SettingsStore, _ calendars: CalendarStore) -> some View {
        MenuContent(openSettings: {}, fixedNow: SampleData.now)
            .environment(store)
            .environment(calendars)
            .environment(PopoverState())
    }

    /// Rows with calls, the upcoming one drawn hovered so its Join button shows.
    private static var callRows: some View {
        let calls = SampleData.events(now: SampleData.now).filter { $0.meetingURL != nil }
        return VStack(spacing: Theme.rowSpacing) {
            ForEach(Array(calls.enumerated()), id: \.element.id) { index, event in
                EventRow(event: event, now: SampleData.now, showsHoverState: index == 1)
            }
        }
        .popoverFrame()
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

    /// Renders the view like the popover: on a stand-in for its glass, rounded, over a
    /// colorful desktop-like backdrop. A real offscreen NSPopover can't be used because its
    /// glass samples what's behind it, which offscreen is nothing.
    private static func snapPopover(_ view: some View, name: String, dark: Bool, dir: URL) {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let framed = view
            .background {
                ZStack {
                    Wallpaper(dark: dark).blur(radius: 40, opaque: true)
                    shape.fill(dark ? Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.72) : Color(red: 0.97, green: 0.97, blue: 0.98).opacity(0.62))
                    shape.fill(LinearGradient(colors: [Color.white.opacity(dark ? 0.06 : 0.30), .clear], startPoint: .top, endPoint: .center))
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(dark ? 0.10 : 0.55), lineWidth: 0.5).padding(0.5))
            .overlay(shape.strokeBorder(Color.black.opacity(dark ? 0.55 : 0.16), lineWidth: 0.5))
            .shadow(color: .black.opacity(dark ? 0.5 : 0.25), radius: 20, y: 10)
            .padding(32)
            .background(Wallpaper(dark: dark))
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

    private static func snapWindow(_ view: some View, name: String, dark: Bool, dir: URL, size: NSSize = NSSize(width: 640, height: 460)) {
        let controller = NSHostingController(rootView: view)
        controller.sceneBridgingOptions = [.toolbars]
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.setContentSize(size)
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

/// A colorful gradient standing in for the desktop picture behind the popover.
private struct Wallpaper: View {
    let dark: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: dark
                           ? [Color(red: 0.05, green: 0.07, blue: 0.16), Color(red: 0.10, green: 0.13, blue: 0.30), Color(red: 0.18, green: 0.12, blue: 0.30)]
                           : [Color(red: 0.16, green: 0.27, blue: 0.52), Color(red: 0.30, green: 0.42, blue: 0.70), Color(red: 0.56, green: 0.45, blue: 0.68)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { proxy in
                Ellipse().fill(Color(red: 0.20, green: 0.70, blue: 0.85).opacity(dark ? 0.35 : 0.45))
                    .frame(width: proxy.size.width * 0.9, height: proxy.size.height * 0.4)
                    .position(x: proxy.size.width * 0.8, y: proxy.size.height * 0.1)
                    .blur(radius: 70)
                Ellipse().fill(Color(red: 0.95, green: 0.45, blue: 0.55).opacity(dark ? 0.30 : 0.45))
                    .frame(width: proxy.size.width * 0.8, height: proxy.size.height * 0.4)
                    .position(x: proxy.size.width * 0.1, y: proxy.size.height * 0.85)
                    .blur(radius: 80)
            }
        }
        .compositingGroup()
    }
}

/// A plausible week of events around today, for snapshots only.
private enum SampleData {
    /// Mid-morning today, so the agenda has past and upcoming events and a Next up card.
    static var now: Date {
        Calendar.current.date(bySettingHour: 10, minute: 40, second: 0, of: .now) ?? .now
    }

    static let calendars = [
        CalendarInfo(id: "work", title: "Work", sourceTitle: "iCloud", color: ItemColor(red: 0.2, green: 0.5, blue: 1), isWritable: true),
        CalendarInfo(id: "home", title: "Home", sourceTitle: "iCloud", color: ItemColor(red: 0.95, green: 0.35, blue: 0.3), isWritable: true),
        CalendarInfo(id: "gym", title: "Training", sourceTitle: "Google", color: ItemColor(red: 0.2, green: 0.75, blue: 0.4), isWritable: true),
        CalendarInfo(id: "holidays", title: "Holidays", sourceTitle: "Other", color: ItemColor(red: 0.6, green: 0.4, blue: 0.9), isWritable: false,
                     isSubscribed: true),
    ]

    /// New York is behind and asleep at the sample time, Tokyo ahead, Honolulu a day behind.
    static let timeZones = [
        WorldClockZone(identifier: "America/New_York", label: "NYC"),
        WorldClockZone(identifier: "Asia/Tokyo"),
        WorldClockZone(identifier: "Pacific/Honolulu"),
    ]

    static let lists = [
        CalendarInfo(id: "todo", title: "To Do", sourceTitle: "iCloud", color: ItemColor(red: 0.2, green: 0.5, blue: 1), isWritable: true),
        CalendarInfo(id: "errands", title: "Errands", sourceTitle: "iCloud", color: ItemColor(red: 1, green: 0.6, blue: 0.1), isWritable: true),
    ]

    static func reminders(now: Date) -> [ReminderItem] {
        let today = Calendar.current.startOfDay(for: now)
        func day(_ offset: Int, hour: Int? = nil) -> Date {
            Calendar.current.date(byAdding: DateComponents(day: offset, hour: hour ?? 0), to: today)!
        }
        let todo = lists[0].color, errands = lists[1].color
        return [
            ReminderItem(id: "1", listID: "todo", title: "Renew passport", due: day(-26, hour: 10), hasDueTime: true, priority: 1, color: todo),
            ReminderItem(id: "2", listID: "errands", title: "Return library books", due: day(-3), hasDueTime: false, color: errands),
            ReminderItem(id: "3", listID: "todo", title: "Send invoice", due: day(0, hour: 8), hasDueTime: true, color: todo),
            ReminderItem(id: "4", listID: "errands", title: "Buy flowers", due: day(0, hour: 23), hasDueTime: true, color: errands),
        ]
    }

    static func events(now: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(byAdding: DateComponents(day: day, hour: hour, minute: minute), to: today)!
        }
        func color(_ id: String) -> ItemColor { calendars.first { $0.id == id }!.color }
        func event(_ title: String, _ calendarID: String, _ start: Date, _ end: Date, allDay: Bool = false, location: String? = nil,
                   notes: String? = nil, url: URL? = nil, recurring: Bool = false, declined: Bool = false) -> CalendarEvent {
            CalendarEvent(eventIdentifier: "\(title)\(start)", calendarID: calendarID, title: title, start: start, end: end, isAllDay: allDay,
                          location: location, notes: notes, url: url, isRecurring: recurring, isDeclined: declined, color: color(calendarID),
                          meetingURL: MeetingLink.find(in: [url?.absoluteString, location, notes]))
        }
        let teams = "https://eur03.safelinks.protection.outlook.com/?url=https%3A%2F%2Fteams.microsoft.com%2Fl%2Fmeetup-join%2F19%253ameeting_x%2540thread.v2%2F0&data=05"
        var events = [
            event("Design review", "work", at(0, 9), at(0, 9, 30), location: "https://meet.google.com/abc-defg-hij", recurring: true),
            event("Client call", "work", at(0, 11, 15), at(0, 12), location: "Microsoft Teams Meeting",
                  notes: "________________\nJoin the meeting now <\(teams)>"),
            event("Lunch with Sara", "home", at(0, 12, 30), at(0, 13, 30), location: "Trattoria da Mario"),
            event("Quarterly planning", "work", at(0, 15), at(0, 16), url: URL(string: "https://example.com/plan")),
            event("Old sync", "work", at(0, 17), at(0, 17, 30), declined: true),
            event("Running", "gym", at(0, 19), at(0, 20), recurring: true),
            event("Company offsite", "work", at(1, 0), at(3, 0), allDay: true),
            event("Dentist", "home", at(2, 10), at(2, 11)),
            event("1:1 with Marco", "work", at(1, 14), at(1, 14, 30), url: URL(string: "https://us02web.zoom.us/j/8812345678"), recurring: true),
        ]
        for offset in [-9, -6, -2, 4, 8, 11, 15, 18] {
            events.append(event("Standup", "work", at(offset, 9), at(offset, 9, 15), recurring: true))
        }
        for (offset, name) in [(-5, "Harvest Day"), (0, "Founders' Day"), (12, "Autumn Bank Holiday")] {
            events.append(event(name, "holidays", at(offset, 0), at(offset + 1, 0), allDay: true))
        }
        return events
    }
}
