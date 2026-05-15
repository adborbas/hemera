import SwiftUI

public struct VerticalSlider: View {
    public struct Configuration {
        public static let defaultTrackFill = AnyShapeStyle(PlatformColor.systemGray3)
        public static let defaultSliderFill = AnyShapeStyle(PlatformColor.systemGreen)

        public struct PickerGradient {
            public var colors: [Color]
            public var startPoint: UnitPoint
            public var endPoint: UnitPoint

            public init(colors: [Color],
                        startPoint: UnitPoint = .bottom,
                        endPoint: UnitPoint = .top) {
                self.colors = colors
                self.startPoint = startPoint
                self.endPoint = endPoint
            }
        }

        public var range: ClosedRange<Double>
        public var style: Style
        public var trackFill: AnyShapeStyle
        public var sliderFill: AnyShapeStyle
        public var pickerGradient: PickerGradient?

        public init(range: ClosedRange<Double> = 0...1,
                    style: Style,
                    trackFill: AnyShapeStyle? = nil,
                    sliderFill: AnyShapeStyle? = nil) {
            self.range = range
            self.style = style
            self.trackFill = trackFill ?? Self.defaultTrackFill
            self.sliderFill = sliderFill ?? Self.defaultSliderFill
        }

        // Numeric mapping helpers

        func fraction(for value: Double) -> CGFloat {
            let clampedValue = min(max(value, range.lowerBound), range.upperBound)
            let span = range.upperBound - range.lowerBound
            guard span != 0 else { return 0 }
            return CGFloat((clampedValue - range.lowerBound) / span)
        }

        func value(for fraction: CGFloat) -> Double {
            let f = fraction.clamped(to: 0...1)
            let span = range.upperBound - range.lowerBound
            return range.lowerBound + Double(f) * span
        }

        // Styling helpers

        func trackFill<S: ShapeStyle>(_ style: S) -> Configuration {
            var copy = self
            copy.trackFill = AnyShapeStyle(style)
            return copy
        }

        func sliderFill<S: ShapeStyle>(_ style: S) -> Configuration {
            var copy = self
            copy.sliderFill = AnyShapeStyle(style)
            return copy
        }

        func pickerFill(colors: [Color],
                        startPoint: UnitPoint = .bottom,
                        endPoint: UnitPoint = .top) -> Configuration {
            var copy = self
            copy.pickerGradient = PickerGradient(
                colors: colors,
                startPoint: startPoint,
                endPoint: endPoint
            )
            return copy
        }
    }

    public enum Style {
        case fill(Anchor)
        case picker
    }

    public enum Anchor {
        case top
        case bottom
    }

    // MARK: - Stored properties

    @Binding var value: Double
    var configuration: Configuration
    public let onCommit: (Double) -> Void
    @State private var didActivateThisGesture = false
    @State private var inInitialDeadZone = false

    // MARK: - Initializers

    public init(value: Binding<Double>,
                configuration: Configuration,
                onCommit: @escaping (Double) -> Void = { _ in }) {
        self._value = value
        self.configuration = configuration
        self.onCommit = onCommit
    }

    public init(value: Binding<Double>,
                style: Style,
                onCommit: @escaping (Double) -> Void = { _ in }) {
        self.init(
            value: value,
            configuration: Configuration(style: style),
            onCommit: onCommit
        )
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let fraction = configuration.fraction(for: value)

            ZStack {
                if case .picker = configuration.style,
                   let pg = configuration.pickerGradient,
                   !pg.colors.isEmpty {
                    trackShape(for: width).fill(
                        Self.adjustedGradient(
                            colors: pg.colors,
                            startPoint: pg.startPoint,
                            endPoint: pg.endPoint,
                            height: height,
                            inset: Self.cornerRadius(for: width)
                        )
                    )
                } else {
                    trackShape(for: width)
                        .fill(configuration.trackFill)
                }

                switch configuration.style {
                case .fill(let anchor):
                    VerticalSliderFillContent(
                        configuration: configuration,
                        width: width,
                        height: height,
                        fraction: fraction,
                        anchor: anchor
                    )
                case .picker:
                    VerticalSliderPickerContent(
                        configuration: configuration,
                        width: width,
                        height: height,
                        fraction: fraction
                    )
                }
            }
            .clipShape(trackShape(for: width))
            .contentShape(trackShape(for: width))
            .frame(maxWidth: .infinity)
            .gesture(sliderGesture(height: height, width: width))
        }
    }

    // MARK: - Helpers

    fileprivate static func cornerRadius(for width: CGFloat) -> CGFloat {
        min(Mortar.Radii.xl, width / 2)
    }

    private func trackShape(for width: CGFloat) -> RoundedRectangle {
        RoundedRectangle(
            cornerRadius: Self.cornerRadius(for: width),
            style: .continuous
        )
    }

    // MARK: Fill gesture

    private func handleFillDrag(y: CGFloat, height: CGFloat, width: CGFloat, anchor: Anchor) {
        let placementPadding = Self.handlePlacementPadding(for: width)
        let handleOffset = placementPadding + Constants.handleHeight / 2
        let minFillHeight = placementPadding * 2 + Constants.handleHeight
        let usableRange = height - minFillHeight
        guard usableRange > 0 else { return }

        let edgeDistance: CGFloat
        switch anchor {
        case .bottom: edgeDistance = height - y
        case .top: edgeDistance = y
        }
        let rawFraction = (edgeDistance - handleOffset) / usableRange
        let currentFraction = configuration.fraction(for: value)

        if currentFraction == 0 && !didActivateThisGesture {
            withAnimation(.easeInOut(duration: Mortar.Motion.normal)) {
                value = configuration.value(for: 0.01)
            }
            didActivateThisGesture = true
            inInitialDeadZone = true
            return
        }

        if currentFraction == 0 { return }

        if inInitialDeadZone && rawFraction <= 0 { return }
        if inInitialDeadZone { inInitialDeadZone = false }

        if rawFraction <= 0 {
            withAnimation(.easeInOut(duration: Mortar.Motion.normal)) {
                value = configuration.range.lowerBound
            }
            didActivateThisGesture = true
        } else {
            let clamped = min(Double(rawFraction), 1.0)
            value = configuration.value(for: 0.01 + clamped * 0.99)
        }
    }

    // MARK: Gesture

    private func sliderGesture(height: CGFloat, width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let locationY = gesture.location.y
                switch configuration.style {
                case .fill(let anchor):
                    handleFillDrag(y: locationY, height: height, width: width, anchor: anchor)
                case .picker:
                    let inset = Self.cornerRadius(for: width)
                    let maxY = height - inset
                    let usable = height - 2 * inset
                    guard usable > 0 else { return }
                    let newFraction = (maxY - locationY) / usable
                    let clampedFraction = newFraction.clamped(to: 0...1)
                    value = configuration.value(for: clampedFraction)
                }
            }
            .onEnded { _ in
                didActivateThisGesture = false
                inInitialDeadZone = false
                onCommit(value)
            }
    }

    // MARK: - Proportional metrics

    fileprivate static func handlePlacementPadding(for width: CGFloat) -> CGFloat {
        min(Constants.handlePlacementPadding, max(Mortar.Spacing.s, width * 0.2))
    }

    fileprivate static func handleHorizontalPadding(for width: CGFloat) -> CGFloat {
        min(Constants.handleHorizontalPadding, max(Mortar.Spacing.xs, width * 0.2))
    }
}

extension VerticalSlider {
    public func sliderFill<S: ShapeStyle>(_ style: S) -> VerticalSlider {
        var copy = self
        copy.configuration = copy.configuration.sliderFill(style)
        return copy
    }

    public func trackFill<S: ShapeStyle>(_ style: S) -> VerticalSlider {
        var copy = self
        copy.configuration = copy.configuration.trackFill(style)
        return copy
    }

    public func pickerFill(colors: [Color],
                           startPoint: UnitPoint = .bottom,
                           endPoint: UnitPoint = .top) -> VerticalSlider {
        var copy = self
        copy.configuration = copy.configuration.pickerFill(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint
        )
        return copy
    }

    static func adjustedGradient(
        colors: [Color],
        startPoint: UnitPoint,
        endPoint: UnitPoint,
        height: CGFloat,
        inset: CGFloat
    ) -> LinearGradient {
        let usable = height - 2 * inset
        guard usable > 0 else {
            return LinearGradient(
                colors: [colors[colors.count / 2]],
                startPoint: startPoint,
                endPoint: endPoint
            )
        }

        let insetFraction = inset / height
        let usableFraction = 1.0 - 2.0 * insetFraction

        var stops: [Gradient.Stop] = []
        stops.append(.init(color: colors.first!, location: 0))

        for (i, color) in colors.enumerated() {
            let t = colors.count > 1
                ? CGFloat(i) / CGFloat(colors.count - 1)
                : 0.5
            stops.append(.init(color: color, location: insetFraction + t * usableFraction))
        }

        stops.append(.init(color: colors.last!, location: 1.0))

        return LinearGradient(stops: stops, startPoint: startPoint, endPoint: endPoint)
    }
}

private struct VerticalSliderFillContent: View {
    let configuration: VerticalSlider.Configuration
    let width: CGFloat
    let height: CGFloat
    let fraction: CGFloat
    let anchor: VerticalSlider.Anchor

    private var placementPadding: CGFloat {
        VerticalSlider.handlePlacementPadding(for: width)
    }

    private var minFillHeight: CGFloat {
        placementPadding + Constants.handleHeight + placementPadding
    }

    private var fillHeight: CGFloat {
        guard fraction > 0 else { return 0 }
        return minFillHeight + fraction * (height - minFillHeight)
    }

    private var handleOffset: CGFloat {
        placementPadding + Constants.handleHeight / 2
    }

    var body: some View {
        ZStack {
            if fraction > 0 {
                VStack(spacing: 0) {
                    if anchor == .top {
                        Rectangle().fill(configuration.sliderFill).frame(height: fillHeight)
                        Spacer(minLength: 0)
                    } else {
                        Spacer(minLength: 0)
                        Rectangle().fill(configuration.sliderFill).frame(height: fillHeight)
                    }
                }
                .transition(.opacity)
            }

            handleOrHint
        }
    }

    private var handleOrHint: some View {
        let handleCenterY: CGFloat
        switch anchor {
        case .bottom:
            handleCenterY = height - fillHeight + handleOffset
        case .top:
            handleCenterY = fillHeight - handleOffset
        }
        let minY = handleOffset
        let maxY = height - handleOffset
        let clampedY = min(max(handleCenterY, minY), maxY)

        return ZStack {
            if fraction > 0 {
                VerticalSliderHandle(availableWidth: width)
                    .frame(width: width)
                    .mortarShadow(.subtle)
                    .position(x: width / 2, y: clampedY)
            } else {
                Group {
                    switch anchor {
                    case .bottom:
                        Image(systemName: "chevron.compact.up")
                    case .top:
                        Image(systemName: "chevron.compact.down")
                    }
                }
                .font(.system(size: min(24, width * 0.5), weight: .semibold))
                .foregroundStyle(PlatformColor.systemGray2)
                .position(x: width / 2, y: clampedY)
            }
        }
    }
}

private struct VerticalSliderPickerContent: View {
    let configuration: VerticalSlider.Configuration
    let width: CGFloat
    let height: CGFloat
    let fraction: CGFloat

    private let pillHeight: CGFloat = 20

    var body: some View {
        let inset = VerticalSlider.cornerRadius(for: width)
        let maxY = height - inset
        let usable = height - 2 * inset
        let y = maxY - fraction * usable
        let pillPadding = min(Mortar.Spacing.l, max(Mortar.Spacing.xs, width * 0.13))

        Capsule(style: .continuous)
            .fill(.thinMaterial)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white, lineWidth: Mortar.strokeWidth)
            )
            .frame(width: width - pillPadding, height: pillHeight)
            .mortarShadow(.medium)
            .position(
                x: width / 2,
                y: y
            )
    }
}

private struct VerticalSliderHandle: View {
    var availableWidth: CGFloat = Constants.defaultTrackWidth

    private var horizontalPadding: CGFloat {
        VerticalSlider.handleHorizontalPadding(for: availableWidth)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Constants.handleHeight)
            .fill(Color.white)
            .frame(height: Constants.handleHeight)
            .padding(.horizontal, horizontalPadding)
    }
}

// MARK: - Constants

private enum Constants {
    static let defaultTrackWidth: CGFloat = 120
    static let handleHeight: CGFloat = 6
    static let handlePlacementPadding: CGFloat = Mortar.Spacing.xxl
    static let handleHorizontalPadding: CGFloat = Mortar.Spacing.xxl
}

// MARK: - Utilities

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Interactive") {
    @Previewable @State var value: Double = 0.5
    @Previewable @State var isAnchoredToBottom: Bool = true
    @Previewable @State var usePicker: Bool = false

    VStack(spacing: Mortar.Spacing.l) {
        Toggle(isOn: $usePicker) {
            Text("Use picker style")
        }

        if !usePicker {
            Toggle(isOn: $isAnchoredToBottom) {
                Text("Fill anchored to bottom")
            }
        }

        let style: VerticalSlider.Style = usePicker
            ? .picker
            : .fill(isAnchoredToBottom ? .bottom : .top)

        VerticalSlider(
            value: $value,
            style: style
        )
        .trackFill(PlatformColor.systemGray3)
        .pickerFill(colors: [.yellow, .white])
    }
    .padding(Mortar.Spacing.m)
}
#endif
