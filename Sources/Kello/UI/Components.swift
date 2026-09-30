import KelloCore
import SwiftUI

extension NSImage {
    /// A calendar color dot for menus and pickers, which render SwiftUI shapes as template
    /// images, so it's drawn in AppKit instead.
    static func swatch(_ color: ItemColor, size: CGFloat = 10) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
