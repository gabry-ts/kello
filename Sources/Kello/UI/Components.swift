import KelloCore
import PartitiUI
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

/// Partiti UI's switch without a visible label, named for accessibility. The style draws
/// its label whatever `labelsHidden` says, so the label is left empty instead.
struct RowSwitch: View {
    let title: String
    @Binding var isOn: Bool
    var mini = false

    init(_ title: String, isOn: Binding<Bool>, mini: Bool = false) {
        self.title = title
        self._isOn = isOn
        self.mini = mini
    }

    var body: some View {
        Toggle(isOn: $isOn) { EmptyView() }
            .toggleStyle(PUISwitchStyle(mini: mini))
            .accessibilityLabel(title)
    }
}
