import SwiftUI

/// Kello's look: Liquid Glass controls and soft glass cards sitting on the popover's own
/// glass, calendar colors as washes and capsules, and the accent for today and actions.
enum Theme {
    // MARK: Layout

    static let popoverWidth: CGFloat = 320
    static let popoverPadding: CGFloat = 14
    static var contentWidth: CGFloat { popoverWidth - popoverPadding * 2 }

    /// Vertical rhythm of the popover and the editors.
    static let spacing: CGFloat = 12
    static let rowSpacing: CGFloat = 6

    /// The agenda and reminders under the grid, fixed so the popover keeps one height.
    static let listHeight: CGFloat = 320

    // MARK: Radii

    /// The grid, the Next up card and the editor sections.
    static let cardRadius: CGFloat = 20
    /// Grouped reminders and the permission rows.
    static let groupRadius: CGFloat = 16
    /// One event.
    static let rowRadius: CGFloat = 14

    // MARK: Controls

    /// Round toolbar buttons and the height of the Today pill.
    static let controlSize: CGFloat = 30
    static let segmentHeight: CGFloat = 26

    // MARK: Grid

    static let cellHeight: CGFloat = 36
    static let dayCircle: CGFloat = 26
    static let dotSize: CGFloat = 4

    // MARK: Colors

    /// The Join button: a bright call-to-action blue that reads on any calendar tint.
    static let join = Color(red: 0.04, green: 0.52, blue: 0.90)
    static let destructive = Color.red
    /// Holiday day numbers in the grid and the holiday label above a day's agenda.
    static let holiday = Color.red
    /// The sun and moon on the extra clocks.
    static let daytime = Color.orange
    static let nighttime = Color.indigo
    /// The Buy Me a Coffee button, in that site's own yellow.
    static let coffee = Color(red: 1, green: 0.87, blue: 0)

    /// A color made a touch deeper in light mode, so pale calendar colors still read as text.
    static func legible(_ color: Color, _ scheme: ColorScheme) -> Color {
        scheme == .dark ? color : color.mix(with: .black, by: 0.18)
    }

    // MARK: Motion

    /// Short springs for state changes, or a plain fade when Reduce Motion is on.
    static func spring(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.32, bounce: 0.12)
    }

    static let hover = Animation.easeOut(duration: 0.12)
}

// MARK: - Surfaces

/// A card on the popover's glass: a translucent fill with a top sheen and a hairline
/// edge, optionally washed with a color. Painted rather than a nested glass effect, which
/// on top of the popover's own glass muddies text; Increase Contrast firms up the edge.
struct Surface: ViewModifier {
    var radius: CGFloat = Theme.cardRadius
    var tint: Color?
    /// How strongly the tint washes the card.
    var tintAmount: Double = 1
    var elevated = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let dark = colorScheme == .dark
        let high = contrast == .increased
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content.background {
            ZStack {
                shape.fill(Color.white.opacity(dark ? 0.07 : 0.55))
                if let tint {
                    shape.fill(tint.opacity((dark ? 0.18 : 0.12) * tintAmount))
                }
                shape.fill(LinearGradient(
                    colors: [Color.white.opacity(dark ? 0.06 : 0.40), Color.white.opacity(0)],
                    startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(dark ? 0.18 : 0.90), Color.white.opacity(dark ? 0.04 : 0.30)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
                shape.strokeBorder((tint ?? .black).opacity(high ? 0.35 : (dark ? 0.16 : 0.08)), lineWidth: high ? 1 : 0.5)
            }
            .shadow(color: .black.opacity(elevated ? (dark ? 0.22 : 0.06) : 0), radius: 6, y: 2)
        }
    }
}

extension View {
    func surface(radius: CGFloat = Theme.cardRadius, tint: Color? = nil, tintAmount: Double = 1, elevated: Bool = true) -> some View {
        modifier(Surface(radius: radius, tint: tint, tintAmount: tintAmount, elevated: elevated))
    }
}

/// A faint rim on glass controls in dark mode, where glass on a dark popover loses its edge.
struct GlassEdge<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let opacity = contrast == .increased ? 0.35 : (colorScheme == .dark ? 0.12 : 0)
        content.overlay(shape.strokeBorder(Color.white.opacity(opacity), lineWidth: 0.5).allowsHitTesting(false))
    }
}

extension View {
    func glassEdge(_ shape: some InsettableShape) -> some View {
        modifier(GlassEdge(shape: shape))
    }
}

/// A hairline between rows of a grouped card.
struct Hairline: View {
    var leading: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.09))
            .frame(height: 0.5)
            .padding(.leading, leading)
    }
}
