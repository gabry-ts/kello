import KelloCore
import SwiftUI

/// A round Liquid Glass button face for an SF Symbol, used by plain buttons and menus
/// alike, which is why it's a label rather than a button style.
struct GlassCircle: View {
    let systemImage: String
    var isActive = false
    var size: CGFloat = Theme.controlSize
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary.opacity(isEnabled ? 0.8 : 0.3)))
            .contentTransition(.symbolEffect(.replace))
            .frame(width: size, height: size)
            .background {
                Circle().fill(.primary.opacity(isHovered && isEnabled ? 0.06 : 0))
            }
            .glassEffect(isActive ? .regular.tint(.accentColor.opacity(0.18)).interactive() : .regular.interactive(), in: .circle)
            .glassEdge(Circle())
            .contentShape(.circle)
            .onHover { isHovered = $0 }
            .animation(Theme.hover, value: isHovered)
    }
}

/// A plain SF Symbol button with a soft round highlight on hover and press, for places
/// inside a glass control where another glass layer would be too much.
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 28

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
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary.opacity(isEnabled ? 0.8 : 0.3))
                .frame(minWidth: size, minHeight: size)
                .background {
                    Capsule().fill(.primary.opacity(configuration.isPressed ? 0.12 : (isHovered && isEnabled ? 0.07 : 0)))
                }
                .contentShape(.capsule)
                .onHover { isHovered = $0 }
                .animation(Theme.hover, value: isHovered)
        }
    }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
}

/// Tracks the pointer over a view, for row and cell hover highlights.
struct HoverHighlight: ViewModifier {
    var cornerRadius: CGFloat = Theme.rowRadius
    var opacity: Double = 0.05
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.primary.opacity(isHovered ? opacity : 0))
                    .allowsHitTesting(false)
            }
            .onHover { isHovered = $0 }
            .animation(Theme.hover, value: isHovered)
    }
}

extension View {
    func hoverHighlight(cornerRadius: CGFloat = Theme.rowRadius, opacity: Double = 0.05) -> some View {
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
