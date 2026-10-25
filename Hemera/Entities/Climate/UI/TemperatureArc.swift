import CoreGraphics
import Foundation

/// Temperature↔angle mapping and setpoint snapping for `CircularTemperatureSlider`.
struct TemperatureArc {

    /// The track runs clockwise from 135° to 405° (= 45°); the 45°–135° wedge is open.
    static let startAngle: Double = 135
    static let endAngle: Double = 405
    static let sweepAngle: Double = 270

    /// Mirrors `ClimateEntity`'s own default, used when the server reports an unusable step.
    private static let defaultStep: Double = 0.5

    let range: ClosedRange<Double>

    /// Snapping step, and the handle gap. Non-positive falls back: `snap` divides by it.
    let step: Double

    init(range: ClosedRange<Double>, step: Double) {
        self.range = range
        self.step = step > 0 ? step : Self.defaultStep
    }

    // MARK: - Angle Mapping

    func angle(forTemperature temperature: Double) -> Double {
        let fraction = (temperature - range.lowerBound) / (range.upperBound - range.lowerBound)
        return Self.startAngle + min(max(fraction, 0), 1) * Self.sweepAngle
    }

    func temperature(forAngle angle: Double) -> Double {
        let normalized = angle < Self.startAngle ? angle + 360 : angle
        let fraction = (normalized - Self.startAngle) / Self.sweepAngle
        return range.lowerBound + min(max(fraction, 0), 1) * (range.upperBound - range.lowerBound)
    }

    // MARK: - Setpoints

    func snap(_ temperature: Double) -> Double {
        clamped((clamped(temperature) / step).rounded() * step)
    }

    /// Held one step below `high` so the handles can neither cross nor coincide.
    func lowSetpoint(_ temperature: Double, below high: Double) -> Double {
        clamped(min(snap(temperature), high - step))
    }

    /// Held one step above `low`, as `lowSetpoint` is below `high`.
    func highSetpoint(_ temperature: Double, above low: Double) -> Double {
        clamped(max(snap(temperature), low + step))
    }

    /// Rounding onto the step grid, and the one-step handle gap, can both overshoot a bound.
    private func clamped(_ temperature: Double) -> Double {
        min(max(temperature, range.lowerBound), range.upperBound)
    }

    // MARK: - Points

    static func point(center: CGPoint, radius: CGFloat, angleDegrees: Double) -> CGPoint {
        let radians = angleDegrees * Double.pi / 180
        return CGPoint(
            x: center.x + radius * Foundation.cos(radians),
            y: center.y + radius * Foundation.sin(radians)
        )
    }

    static func angle(from point: CGPoint, center: CGPoint) -> Double {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let angle = Foundation.atan2(dy, dx) * 180 / Double.pi
        return angle < 0 ? angle + 360 : angle
    }

    /// Stops a drag crossing the open wedge from jumping the handle end to end.
    static func isOnArc(_ angle: Double) -> Bool {
        let normalized = angle < 0 ? angle + 360 : angle.truncatingRemainder(dividingBy: 360)
        return !(normalized > 45 && normalized < 135)
    }
}
