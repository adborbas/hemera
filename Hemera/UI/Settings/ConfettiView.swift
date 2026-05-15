import SwiftUI

struct ConfettiView: View {

    var onComplete: () -> Void

    @State private var particles: [Particle] = []
    @State private var animating = false

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .mint]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    particle.shape
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .rotationEffect(.degrees(animating ? particle.spinTo : 0))
                        .position(
                            x: animating ? particle.endX : geometry.size.width / 2,
                            y: animating ? particle.endY : -20
                        )
                        .opacity(animating ? 0 : 1)
                }
            }
            .onAppear {
                particles = (0..<50).map { _ in
                    Particle(
                        color: colors.randomElement()!,
                        size: CGFloat.random(in: 6...12),
                        endX: CGFloat.random(in: 0...geometry.size.width),
                        endY: CGFloat.random(in: geometry.size.height * 0.3...geometry.size.height),
                        spinTo: Double.random(in: 180...720) * (Bool.random() ? 1 : -1),
                        shape: [AnyShape(Rectangle()), AnyShape(Circle()), AnyShape(Capsule())].randomElement()!
                    )
                }
                withAnimation(.easeOut(duration: 2.0)) {
                    animating = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    onComplete()
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let spinTo: Double
    let shape: AnyShape
}
