import AppKit
import SwiftUI

/// `Kello --render-icon <dir>` writes AppIcon.iconset, which `scripts/make-icon.sh` then
/// turns into AppIcon.icns with `iconutil`. Never touches the real settings.json.
@MainActor
enum Snapshots {
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
}
