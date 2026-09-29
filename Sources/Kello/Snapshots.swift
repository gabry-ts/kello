import AppKit
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

        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            snapPopover(MenuContent(openSettings: {}).environment(store), name: "popover-\(suffix)", dark: dark, dir: dir)
        }
        snapPopover(MenuContent(openSettings: {}).environment(weekNumbersStore), name: "popover-weeknumbers-light", dark: false, dir: dir)
        print("Snapshots written to \(dir.path)")
        return 0
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
