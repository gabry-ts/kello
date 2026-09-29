import KelloCore
import SwiftUI

/// A borderless SF Symbol button that shows a soft rounded highlight on hover and press.
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, size: size)
    }

    private struct IconButtonBody: View {
        let configuration: Configuration
        let size: CGFloat
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isEnabled ? .secondary : .tertiary)
                .frame(width: size, height: size)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.primary.opacity(configuration.isPressed ? 0.14 : (isHovered && isEnabled ? 0.08 : 0)))
                }
                .contentShape(.rect)
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
    }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
}

/// Tracks the pointer over a view, for row and cell hover highlights.
struct HoverHighlight: ViewModifier {
    var cornerRadius: CGFloat = 6
    var opacity: Double = 0.06
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.primary.opacity(isHovered ? opacity : 0))
            }
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

extension View {
    func hoverHighlight(cornerRadius: CGFloat = 6, opacity: Double = 0.06) -> some View {
        modifier(HoverHighlight(cornerRadius: cornerRadius, opacity: opacity))
    }
}

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
