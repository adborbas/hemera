import Mortar
import SwiftUI

/// The wave left of the thumb grows with the value, as in Zen's opacity slider.
struct WavySlider: View {
    let label: String
    @Binding var value: Double
    let onActive: (Bool) -> Void

    @State private var dragValue: Double?
    @State private var throttle = DragThrottle()

    private var fraction: Double { dragValue ?? value }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width, mid = proxy.size.height / 2
            let thumbX = Self.thumbWidth / 2 + fraction * (width - Self.thumbWidth)
            ZStack(alignment: .leading) {
                Canvas { context, _ in
                    var wave = Path()
                    let amplitude = 2 + fraction * 10
                    for x in stride(from: 0, through: thumbX, by: 1) {
                        let point = CGPoint(x: x, y: mid + sin(x / 7 + fraction * 12) * amplitude)
                        if x == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
                    }
                    context.stroke(wave, with: .style(.primary), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    let rest = Path { $0.move(to: CGPoint(x: thumbX, y: mid)); $0.addLine(to: CGPoint(x: width, y: mid)) }
                    context.stroke(rest, with: .style(.tertiary), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                Capsule()
                    .fill(.white)
                    .mortarShadow(.soft)
                    .frame(width: Self.thumbWidth, height: 36)
                    .position(x: thumbX, y: mid)
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    if dragValue == nil { onActive(true) }
                    dragValue = min(1, max(0, (drag.location.x - Self.thumbWidth / 2) / (width - Self.thumbWidth)))
                    if throttle.ready(), let dragValue { value = dragValue }
                }
                .onEnded { _ in
                    if let dragValue { value = dragValue }
                    dragValue = nil
                    onActive(false)
                })
            .sensoryFeedback(.selection, trigger: Int(fraction * 10))
        }
        .frame(height: 44)
        .accessibilityRepresentation {
            Slider(value: $value, in: 0...1) { Text(label) }
        }
    }

    private static let thumbWidth: CGFloat = 14
}

/// Lets a dragged value through at most every 100 ms, so the themed screens don't redraw per touch event.
struct DragThrottle {
    private var last = Date.distantPast

    mutating func ready() -> Bool {
        guard Date().timeIntervalSince(last) > 0.1 else { return false }
        last = Date()
        return true
    }
}
