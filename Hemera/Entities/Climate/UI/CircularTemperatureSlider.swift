import SwiftUI
import Mortar

/// A circular thermostat-style slider for setting target temperature.
///
/// Supports single-setpoint mode (one handle) and range mode (two handles for low/high targets).
/// Current temperature is shown as a filled marker on the arc; target temperatures are draggable ring handles.
struct CircularTemperatureSlider: View {
    @Binding var targetTemperature: Double
    @Binding var targetLow: Double
    @Binding var targetHigh: Double
    var currentTemperature: Double?
    var range: ClosedRange<Double>
    var tintColor: Color
    var arcGradientColors: [Color]?
    var lowHandleColor: Color?
    var highHandleColor: Color?
    var step: Double
    var temperatureFormatter: (Double) -> String
    var isRangeMode: Bool
    var onCommitSingle: ((Double) -> Void)?
    var onCommitRange: ((Double, Double) -> Void)?

    @State private var activeHandle: Handle?

    private enum Handle {
        case single
        case low
        case high
    }

    // MARK: - Default Formatter

    private static func defaultFormatter(_ temp: Double) -> String {
        if temp == temp.rounded() {
            return "\(Int(temp))\u{00B0}"
        }
        return String(format: "%.1f\u{00B0}", temp)
    }

    // MARK: - Geometry Constants

    private static let startAngle: Double = 135
    private static let endAngle: Double = 405
    private static let sweepAngle: Double = 270
    private static let trackWidth: CGFloat = 20
    private static let handleRadius: CGFloat = 14
    private static let currentTempMarkerRadius: CGFloat = handleRadius - 2

    // MARK: - Init (Single Setpoint)

    init(
        targetTemperature: Binding<Double>,
        currentTemperature: Double?,
        range: ClosedRange<Double>,
        tintColor: Color,
        step: Double = 0.5,
        temperatureFormatter: @escaping (Double) -> String = Self.defaultFormatter,
        onCommit: @escaping (Double) -> Void
    ) {
        self._targetTemperature = targetTemperature
        self._targetLow = .constant(0)
        self._targetHigh = .constant(0)
        self.currentTemperature = currentTemperature
        self.range = range
        self.tintColor = tintColor
        self.arcGradientColors = nil
        self.lowHandleColor = nil
        self.highHandleColor = nil
        self.step = step
        self.temperatureFormatter = temperatureFormatter
        self.isRangeMode = false
        self.onCommitSingle = onCommit
        self.onCommitRange = nil
    }

    // MARK: - Init (Range)

    init(
        targetLow: Binding<Double>,
        targetHigh: Binding<Double>,
        currentTemperature: Double?,
        range: ClosedRange<Double>,
        tintColor: Color,
        arcGradientColors: [Color]? = nil,
        lowHandleColor: Color? = nil,
        highHandleColor: Color? = nil,
        step: Double = 0.5,
        temperatureFormatter: @escaping (Double) -> String = Self.defaultFormatter,
        onCommit: @escaping (Double, Double) -> Void
    ) {
        self._targetTemperature = .constant(0)
        self._targetLow = targetLow
        self._targetHigh = targetHigh
        self.currentTemperature = currentTemperature
        self.range = range
        self.tintColor = tintColor
        self.arcGradientColors = arcGradientColors
        self.lowHandleColor = lowHandleColor
        self.highHandleColor = highHandleColor
        self.step = step
        self.temperatureFormatter = temperatureFormatter
        self.isRangeMode = true
        self.onCommitSingle = nil
        self.onCommitRange = onCommit
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let arcRadius = (size - Self.trackWidth - Self.handleRadius * 2) / 2

            ZStack {
                // Temperature scale arc
                if let gradientColors = arcGradientColors {
                    arcPath(center: center, radius: arcRadius)
                        .stroke(
                            AngularGradient(
                                colors: gradientColors,
                                center: .center,
                                startAngle: .degrees(Self.startAngle),
                                endAngle: .degrees(Self.endAngle)
                            ),
                            style: StrokeStyle(lineWidth: Self.trackWidth, lineCap: .round)
                        )
                        .opacity(0.3)
                } else {
                    arcPath(center: center, radius: arcRadius)
                        .stroke(
                            tintColor.opacity(0.3),
                            style: StrokeStyle(lineWidth: Self.trackWidth, lineCap: .round)
                        )
                }

                // Current temperature marker
                if let current = currentTemperature,
                   current >= range.lowerBound && current <= range.upperBound {
                    currentTempMarker(center: center, radius: arcRadius, temperature: current)
                }

                // Target handle(s)
                if isRangeMode {
                    handleView(center: center, radius: arcRadius, temperature: targetLow, color: lowHandleColor ?? tintColor)
                    handleView(center: center, radius: arcRadius, temperature: targetHigh, color: highHandleColor ?? tintColor)
                } else {
                    handleView(center: center, radius: arcRadius, temperature: targetTemperature, color: tintColor)
                }

                // Center text
                centerDisplay
            }
            .gesture(dragGesture(center: center, radius: arcRadius))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Arc Paths

    private func arcPath(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(Self.startAngle),
                endAngle: .degrees(Self.endAngle),
                clockwise: false
            )
        }
    }

    // MARK: - Markers & Handles

    private func currentTempMarker(center: CGPoint, radius: CGFloat, temperature: Double) -> some View {
        let angle = angleForTemperature(temperature)
        let point = pointOnArc(center: center, radius: radius, angleDegrees: angle)
        return Circle()
            .fill(Color(PlatformColor.systemGray2))
            .frame(width: Self.currentTempMarkerRadius * 2, height: Self.currentTempMarkerRadius * 2)
            .position(point)
    }

    private func handleView(center: CGPoint, radius: CGFloat, temperature: Double, color: Color) -> some View {
        let angle = angleForTemperature(temperature)
        let point = pointOnArc(center: center, radius: radius, angleDegrees: angle)
        return Circle()
            .fill(color)
            .frame(width: Self.handleRadius * 2, height: Self.handleRadius * 2)
            .mortarShadow(.soft)
            .position(point)
    }

    // MARK: - Center Display

    private var centerDisplay: some View {
        VStack(spacing: Mortar.Spacing.xs) {
            if let current = currentTemperature {
                Text(temperatureFormatter(current))
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .contentTransition(.numericText())
            }

            if isRangeMode {
                Text(Localization.targetRange(
                    temperatureFormatter(targetLow),
                    temperatureFormatter(targetHigh)
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            } else {
                Text(Localization.target(temperatureFormatter(targetTemperature)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: - Gesture

    private func dragGesture(center: CGPoint, radius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let location = gesture.location
                let angle = angleFromPoint(location, center: center)

                guard isAngleOnArc(angle) else { return }

                let temperature = temperatureForAngle(angle)

                if activeHandle == nil {
                    activeHandle = closestHandle(to: temperature)
                }

                updateTemperature(temperature, for: activeHandle)
            }
            .onEnded { _ in
                if isRangeMode {
                    onCommitRange?(targetLow, targetHigh)
                } else {
                    onCommitSingle?(targetTemperature)
                }
                activeHandle = nil
            }
    }

    private func closestHandle(to temperature: Double) -> Handle {
        if !isRangeMode { return .single }

        let distLow = abs(temperature - targetLow)
        let distHigh = abs(temperature - targetHigh)
        return distLow <= distHigh ? .low : .high
    }

    private func updateTemperature(_ temperature: Double, for handle: Handle?) {
        let clamped = min(max(temperature, range.lowerBound), range.upperBound)
        let stepped = (clamped / step).rounded() * step

        switch handle {
        case .single:
            targetTemperature = stepped
        case .low:
            targetLow = min(stepped, targetHigh - 1)
        case .high:
            targetHigh = max(stepped, targetLow + 1)
        case nil:
            break
        }
    }

    // MARK: - Angle / Temperature Mapping

    private func angleForTemperature(_ temperature: Double) -> Double {
        let fraction = (temperature - range.lowerBound) / (range.upperBound - range.lowerBound)
        let clampedFraction = min(max(fraction, 0), 1)
        return Self.startAngle + clampedFraction * Self.sweepAngle
    }

    private func temperatureForAngle(_ angle: Double) -> Double {
        let normalizedAngle = angle < Self.startAngle ? angle + 360 : angle
        let fraction = (normalizedAngle - Self.startAngle) / Self.sweepAngle
        let clampedFraction = min(max(fraction, 0), 1)
        return range.lowerBound + clampedFraction * (range.upperBound - range.lowerBound)
    }

    private func pointOnArc(center: CGPoint, radius: CGFloat, angleDegrees: Double) -> CGPoint {
        let radians = angleDegrees * Double.pi / 180
        return CGPoint(
            x: center.x + radius * Foundation.cos(radians),
            y: center.y + radius * Foundation.sin(radians)
        )
    }

    private func angleFromPoint(_ point: CGPoint, center: CGPoint) -> Double {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        var angle = Foundation.atan2(dy, dx) * 180 / Double.pi
        if angle < 0 { angle += 360 }
        return angle
    }

    private func isAngleOnArc(_ angle: Double) -> Bool {
        // The arc goes from 135° to 405° (45°). The gap is from 45° to 135°.
        // An angle is on the arc if it's NOT in the gap.
        let normalizedAngle = angle < 0 ? angle + 360 : angle.truncatingRemainder(dividingBy: 360)
        // Gap is from 45° to 135°
        return !(normalizedAngle > 45 && normalizedAngle < 135)
    }
}

// MARK: - Localization

private extension CircularTemperatureSlider {
    enum Localization {
        static func target(_ temp: String) -> String {
            String(localized: "Target: \(temp)",
                   comment: "Label below current temperature showing the target temperature value on the circular thermostat slider")
        }

        static func targetRange(_ low: String, _ high: String) -> String {
            String(localized: "\(low) – \(high)",
                   comment: "Label showing the target temperature range (low to high) on the circular thermostat slider")
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Single Setpoint") {
    @Previewable @State var target: Double = 22

    CircularTemperatureSlider(
        targetTemperature: $target,
        currentTemperature: 19.8,
        range: 7...35,
        tintColor: .warm,
        onCommit: { _ in }
    )
    .frame(width: 240, height: 240)
}

#Preview("Range Mode") {
    @Previewable @State var low: Double = 18
    @Previewable @State var high: Double = 24

    CircularTemperatureSlider(
        targetLow: $low,
        targetHigh: $high,
        currentTemperature: 21.3,
        range: 7...35,
        tintColor: .cool,
        onCommit: { _, _ in }
    )
    .frame(width: 240, height: 240)
}
#endif
