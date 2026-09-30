import SwiftUI

/// The app icon, drawn in a 1024 × 1024 space: a blue squircle covering 82% of the
/// canvas (the standard macOS icon padding) with a white clock face, its hands set to a
/// friendly "ten past ten", and a small calendar tab peeking out above it.
struct AppIconView: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 1024
            ctx.scaleBy(x: s, y: s)
            let body = CGRect(x: 92, y: 92, width: 840, height: 840)
            let squircle = Path(roundedRect: body, cornerRadius: 188, style: .continuous)
            let navy = Color(red: 0.13, green: 0.22, blue: 0.55)

            // Drop shadow.
            var shadowCtx = ctx
            shadowCtx.addFilter(.shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 12))
            shadowCtx.fill(squircle, with: .color(Color(red: 0.16, green: 0.32, blue: 0.78)))

            // Body: cool sky blue to deep indigo.
            ctx.fill(squircle, with: .linearGradient(
                Gradient(colors: [Color(red: 0.38, green: 0.64, blue: 0.98), Color(red: 0.16, green: 0.28, blue: 0.72)]),
                startPoint: CGPoint(x: 512, y: 92), endPoint: CGPoint(x: 512, y: 932)))

            // Soft top sheen and hairline inner edge.
            ctx.fill(squircle, with: .linearGradient(
                Gradient(colors: [.white.opacity(0.22), .white.opacity(0)]),
                startPoint: CGPoint(x: 512, y: 92), endPoint: CGPoint(x: 512, y: 520)))
            ctx.stroke(Path(roundedRect: body.insetBy(dx: 2, dy: 2), cornerRadius: 186, style: .continuous),
                       with: .color(.white.opacity(0.18)), lineWidth: 4)

            // Calendar tab: a small page peeking out above the clock, with a colored
            // header strip and two binder rings, tucked slightly behind the clock face.
            let tabRect = CGRect(x: 392, y: 120, width: 240, height: 100)
            let tabPath = Path(roundedRect: tabRect, cornerRadius: 24, style: .continuous)
            var tabShadowCtx = ctx
            tabShadowCtx.addFilter(.shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 6))
            tabShadowCtx.fill(tabPath, with: .color(.white))

            let ringCenters = [CGPoint(x: 452, y: 112), CGPoint(x: 572, y: 112)]
            for center in ringCenters {
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - 16, y: center.y - 16, width: 32, height: 32)), with: .color(navy))
            }

            var headerCtx = ctx
            headerCtx.clip(to: tabPath)
            headerCtx.fill(Path(CGRect(x: tabRect.minX, y: tabRect.minY, width: tabRect.width, height: 38)),
                           with: .color(Color(red: 0.96, green: 0.44, blue: 0.40)))

            // Clock face.
            let center = CGPoint(x: 512, y: 528)
            let radius: CGFloat = 300
            let face = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            var faceShadowCtx = ctx
            faceShadowCtx.addFilter(.shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 8))
            faceShadowCtx.fill(face, with: .color(.white))
            ctx.stroke(face, with: .color(navy.opacity(0.18)), lineWidth: 6)

            // Hands, pointing to a friendly "ten past ten".
            func handTip(hours: Double, length: CGFloat) -> CGPoint {
                let angle = hours / 12 * 2 * .pi - .pi / 2
                return CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
            }
            var handCtx = ctx
            handCtx.addFilter(.shadow(color: navy.opacity(0.3), radius: 6, x: 0, y: 4))
            var hourHand = Path()
            hourHand.move(to: center)
            hourHand.addLine(to: handTip(hours: 10, length: radius * 0.52))
            handCtx.stroke(hourHand, with: .color(navy), style: StrokeStyle(lineWidth: 52, lineCap: .round))
            var minuteHand = Path()
            minuteHand.move(to: center)
            minuteHand.addLine(to: handTip(hours: 2, length: radius * 0.8))
            handCtx.stroke(minuteHand, with: .color(navy), style: StrokeStyle(lineWidth: 40, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52)), with: .color(navy))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

extension AppIconView {
    /// The icon rendered once into a `SwiftUI.Image`, for contexts that need an image
    /// rather than a view, such as Partiti UI's `AboutPane`.
    @MainActor static let image: Image = {
        let renderer = ImageRenderer(content: AppIconView().frame(width: 256, height: 256))
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else { return Image(systemName: "clock") }
        return Image(decorative: cgImage, scale: 2)
    }()
}
