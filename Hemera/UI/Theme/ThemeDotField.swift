import SwiftUI

/// Angle picks the hue, distance from the centre the radius; dots swell around the handle.
struct ThemeDotField: View {
    let family: ThemeFamily
    let hue: Double
    let radius: Double
    /// None has no pick to show until a touch makes one.
    let showsHandle: Bool
    let pick: (_ hue: Double, _ radius: Double) -> Void
    let onActive: (Bool) -> Void

    @State private var drag: (hue: Double, radius: Double)?
    @State private var throttle = DragThrottle()
    @Environment(\.colorScheme) private var colorScheme

    private var shownHue: Double { drag?.hue ?? hue }
    private var shownRadius: Double { drag?.radius ?? radius }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let handle = showsHandle || drag != nil ? point(hue: shownHue, radius: shownRadius, size: size) : nil
            let color = family.color(hue: shownHue, radius: shownRadius).swiftUIColor
            ZStack {
                Canvas { context, canvas in
                    drawDots(in: &context, size: canvas.width, handle: handle)
                }
                if let handle {
                    Circle()
                        .fill(color)
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .shadow(color: color.opacity(0.8), radius: 12)
                        .frame(width: 40, height: 40)
                        .position(handle)
                }
            }
            .frame(width: size, height: size)
            .contentShape(.circle)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { update(with: $0.location, size: size) }
                .onEnded { _ in end() })
            .sensoryFeedback(.selection, trigger: Int(shownHue * 24))
        }
    }

    private func drawDots(in context: inout GraphicsContext, size: CGFloat, handle: CGPoint?) {
        let step: CGFloat = 12, half = size / 2
        let rings = Int(half / step)
        for row in -rings...rings {
            for column in -rings...rings {
                let x = half + CGFloat(column) * step, y = half + CGFloat(row) * step
                let dx = x - half, dy = y - half
                // Half a step in from the edge, so the outer rows don't end in a lone stub of dots.
                let distance = hypot(dx, dy) / (half - step / 2)
                guard distance <= 1 else { continue }
                let angle = atan2(dy, dx) / (2 * .pi)
                let swell = handle.map { max(0, 1 - hypot(x - $0.x, y - $0.y) / 56) } ?? 0
                let diameter = 4 + 6 * swell
                let rect = CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)
                let isLight = colorScheme == .light
                let color = family.color(hue: angle < 0 ? angle + 1 : angle, radius: max(distance, isLight ? 0.3 : 0.15))
                if isLight {
                    // Pale dots vanish on a white sheet without an edge.
                    context.fill(Path(ellipseIn: rect.insetBy(dx: -0.75, dy: -0.75)), with: .color(.black.opacity(0.12)))
                }
                context.fill(Path(ellipseIn: rect), with: .color(color.swiftUIColor))
            }
        }
    }

    private func update(with location: CGPoint, size: CGFloat) {
        let dx = location.x - size / 2, dy = location.y - size / 2
        let angle = atan2(dy, dx) / (2 * .pi)
        if drag == nil { onActive(true) }
        drag = (angle < 0 ? angle + 1 : angle, min(1, hypot(dx, dy) / (size / 2)))
        if throttle.ready() { push() }
    }

    private func end() {
        push()
        drag = nil
        onActive(false)
    }

    private func push() {
        guard let drag else { return }
        pick(drag.hue, drag.radius)
    }

    private func point(hue: Double, radius: Double, size: CGFloat) -> CGPoint {
        let angle = hue * 2 * .pi, distance = radius * size / 2
        return CGPoint(x: size / 2 + cos(angle) * distance, y: size / 2 + sin(angle) * distance)
    }
}
