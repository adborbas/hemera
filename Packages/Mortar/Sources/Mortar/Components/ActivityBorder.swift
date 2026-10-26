import SwiftUI

/**
 Indeterminate progress for a long-running entity: a segment travelling the border of
 a rounded rectangle. Driven per frame so it wraps past the start without a jump.
 */
public struct ActivityBorder: View {

    // MARK: - Properties

    private let color: Color
    private let isActive: Bool
    private let cornerRadius: CGFloat
    private let lineWidth: CGFloat
    private let segment: CGFloat
    private let speed: CGFloat

    // MARK: - Init

    /// - Parameter speed: points per second, so the segment travels alike on every card size.
    public init(
        color: Color,
        isActive: Bool,
        cornerRadius: CGFloat = Mortar.Radii.l,
        lineWidth: CGFloat = 3,
        segment: CGFloat = 0.16,
        speed: CGFloat = Mortar.Motion.borderTravelSpeed
    ) {
        self.color = color
        self.isActive = isActive
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.segment = segment
        self.speed = speed
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            if isActive {
                GeometryReader { geometry in
                    TimelineView(.animation) { context in
                        let head = phase(at: context.date, period: period(in: geometry.size))
                        ZStack {
                            shape.trim(from: head, to: min(head + segment, 1)).stroke(color, style: stroke)
                            if head + segment > 1 {
                                shape.trim(from: 0, to: head + segment - 1).stroke(color, style: stroke)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(Mortar.Motion.springNormal, value: isActive)
        .allowsHitTesting(false)
    }

    // MARK: - Private

    private var shape: some InsettableShape {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .inset(by: lineWidth / 2)
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round)
    }

    /// Straight edges plus the four corner arcs that replace them.
    private func period(in size: CGSize) -> Double {
        let radius = min(cornerRadius, min(size.width, size.height) / 2)
        let perimeter = 2 * (size.width + size.height) - 8 * radius + 2 * .pi * radius
        return Double(max(perimeter, 1) / speed)
    }

    private func phase(at date: Date, period: Double) -> CGFloat {
        CGFloat((date.timeIntervalSinceReferenceDate / period).truncatingRemainder(dividingBy: 1))
    }
}

#if DEBUG
#Preview {
    @Previewable @State var isActive = true

    RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous)
        .fill(PlatformColor.secondarySystemBackground)
        .frame(width: 240, height: 80)
        .overlay {
            ActivityBorder(color: .blue, isActive: isActive)
        }
        .overlay(alignment: .bottomTrailing) {
            Button(isActive ? "Stop" : "Start") { isActive.toggle() }
        }
        .padding()
}
#endif
