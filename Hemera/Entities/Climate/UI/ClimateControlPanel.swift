import SwiftUI
import Mortar

struct ClimateControlPanel: View {
    var viewModel: ClimateCardViewModel
    @Binding var isPresented: Bool

    @State private var targetTemp: Double = 20
    @State private var targetLow: Double = 18
    @State private var targetHigh: Double = 24
    @State private var selectedFanMode: String?
    @State private var selectedSwingMode: String?
    @State private var selectedPresetMode: String?
    @State private var lastActiveMode: ClimateEntity.HVACMode = .heat

    // MARK: - Body

    var body: some View {
        EntityControlPanel(
            isPresented: $isPresented,
            title: viewModel.name,
            subtitle: viewModel.statusLabel
        ) {
            VStack(spacing: Mortar.Spacing.s) {
                mainContent
                if !viewModel.isOff {
                    controlButtons
                }
            }
        } footer: {
            if !viewModel.isOff && hasAdditionalModes {
                additionalModes
            }
        }
        .animation(Mortar.Motion.springBouncy, value: viewModel.hvacMode)
        .onAppear { syncFromEntity() }
        .onChange(of: viewModel.targetTemperature) { _, _ in syncTargetTemp() }
        .onChange(of: viewModel.targetTempLow) { _, _ in syncTargetRange() }
        .onChange(of: viewModel.targetTempHigh) { _, _ in syncTargetRange() }
        .onChange(of: viewModel.currentFanMode) { _, new in selectedFanMode = new }
        .onChange(of: viewModel.currentSwingMode) { _, new in selectedSwingMode = new }
        .onChange(of: viewModel.currentPresetMode) { _, new in selectedPresetMode = new }
        .onChange(of: viewModel.hvacMode) { _, new in
            if new != .off { lastActiveMode = new }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isOff {
            offStateView
                .transition(.blurReplace)
        } else if viewModel.showsTargetControl {
            temperatureSlider
                .transition(.blurReplace)
        } else {
            readOnlyTemperatureDisplay
                .transition(.blurReplace)
        }
    }

    // MARK: - Off State

    @State private var isPressed: Bool = false

    private var offStateView: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(Mortar.Motion.springBouncy) {
                viewModel.togglePower()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(PlatformColor.systemGray5)

                Circle()
                    .strokeBorder(PlatformColor.systemGray4, lineWidth: 4)

                Image(systemName: "power")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(PlatformColor.systemGray2)
            }
            .frame(width: 160, height: 160)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(Mortar.Motion.springBouncy, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    // MARK: - Temperature Range

    /// Sorted, non-degenerate temperature range. Guards against a misconfigured server
    /// reporting `min_temp > max_temp` (ClosedRange traps) or `min_temp == max_temp`
    /// (zero-width span → NaN in the slider fraction divisors).
    private var temperatureRange: ClosedRange<Double> {
        let lo = Swift.min(viewModel.minTemp, viewModel.maxTemp)
        let hi = Swift.max(viewModel.minTemp, viewModel.maxTemp)
        return lo < hi ? lo...hi : lo...(lo + 1)
    }

    // MARK: - Read-Only Temperature Display

    private var readOnlyTemperatureDisplay: some View {
        ReadOnlyTemperatureArc(
            currentTemperature: viewModel.currentTemperature,
            range: temperatureRange,
            tintColor: viewModel.tintColor,
            temperatureFormatter: ClimateCardViewModel.formatTemperature
        )
        .frame(maxWidth: 260, maxHeight: 260)
        .transition(.blurReplace)
    }

    // MARK: - Temperature Slider

    @ViewBuilder
    private var temperatureSlider: some View {
        if viewModel.isRangeMode {
            CircularTemperatureSlider(
                targetLow: $targetLow,
                targetHigh: $targetHigh,
                currentTemperature: viewModel.currentTemperature,
                range: temperatureRange,
                tintColor: viewModel.tintColor,
                arcGradientColors: viewModel.arcGradientColors,
                lowHandleColor: viewModel.lowHandleColor,
                highHandleColor: viewModel.highHandleColor,
                step: viewModel.targetTempStep,
                temperatureFormatter: ClimateCardViewModel.formatTemperature
            ) { low, high in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.setTemperatureRange(low: low, high: high)
            }
            .frame(maxWidth: 260, maxHeight: 260)
        } else if viewModel.supportsTargetTemperature {
            CircularTemperatureSlider(
                targetTemperature: $targetTemp,
                currentTemperature: viewModel.currentTemperature,
                range: temperatureRange,
                tintColor: viewModel.tintColor,
                step: viewModel.targetTempStep,
                temperatureFormatter: ClimateCardViewModel.formatTemperature
            ) { temp in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.setTemperature(temp)
            }
            .frame(maxWidth: 260, maxHeight: 260)
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: Mortar.Spacing.m) {
            // Power toggle
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(Mortar.Motion.springBouncy) {
                    viewModel.togglePower()
                }
            } label: {
                Image(systemName: "power")
                    .font(.title2)
                    .foregroundStyle(PlatformColor.systemGray)
                    .frame(width: Mortar.IconSize.m, height: Mortar.IconSize.m)
                    .background {
                        Circle().fill(PlatformColor.systemGray5)
                    }
            }

            // Mode selector (dropdown)
            let activeModes = viewModel.availableHVACModes.filter { $0 != .off }
            if activeModes.count > 1 {
                Menu {
                    ForEach(activeModes, id: \.self) { mode in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            viewModel.setHVACMode(mode)
                        } label: {
                            Label(viewModel.displayName(for: mode), systemImage: hvacModeIcon(mode))
                        }
                    }
                } label: {
                    Image(systemName: hvacModeIcon(viewModel.hvacMode))
                        .font(.title2)
                        .foregroundStyle(viewModel.tintColor)
                        .frame(width: Mortar.IconSize.m, height: Mortar.IconSize.m)
                        .background {
                            Circle().fill(PlatformColor.systemGray5)
                        }
                }
            }
        }
    }

    // MARK: - Additional Modes

    private var hasAdditionalModes: Bool {
        viewModel.supportsFanMode || viewModel.supportsSwingMode || viewModel.supportsPresetMode
    }

    private var additionalModes: some View {
        HStack(spacing: Mortar.Spacing.s) {
            if viewModel.supportsPresetMode, let presets = viewModel.presetModes, !presets.isEmpty {
                OptionPill(
                    icon: "house.fill",
                    title: Localization.preset,
                    options: presets,
                    selection: $selectedPresetMode
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.setPresetMode($0)
                }
            }

            if viewModel.supportsFanMode, let fans = viewModel.fanModes, !fans.isEmpty {
                OptionPill(
                    icon: "fan.fill",
                    title: Localization.fanMode,
                    options: fans,
                    selection: $selectedFanMode
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.setFanMode($0)
                }
            }

            if viewModel.supportsSwingMode, let swings = viewModel.swingModes, !swings.isEmpty {
                OptionPill(
                    icon: "arrow.up.and.down.and.arrow.left.and.right",
                    title: Localization.swingMode,
                    options: swings,
                    selection: $selectedSwingMode
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.setSwingMode($0)
                }
            }
        }
        .padding(.horizontal, Mortar.Spacing.m)
    }

    // MARK: - Sync

    private func syncFromEntity() {
        targetTemp = viewModel.targetTemperature ?? viewModel.minTemp
        targetLow = viewModel.targetTempLow ?? viewModel.minTemp
        targetHigh = viewModel.targetTempHigh ?? viewModel.maxTemp
        selectedFanMode = viewModel.currentFanMode
        selectedSwingMode = viewModel.currentSwingMode
        selectedPresetMode = viewModel.currentPresetMode
        if !viewModel.isOff {
            lastActiveMode = viewModel.hvacMode
        }
    }

    private func syncTargetTemp() {
        if let temp = viewModel.targetTemperature {
            targetTemp = temp
        }
    }

    private func syncTargetRange() {
        if let low = viewModel.targetTempLow {
            targetLow = low
        }
        if let high = viewModel.targetTempHigh {
            targetHigh = high
        }
    }

    // MARK: - HVAC Mode Icons

    private func hvacModeIcon(_ mode: ClimateEntity.HVACMode) -> String {
        switch mode {
        case .off: "power"
        case .heat: "heat.waves"
        case .cool: "snowflake"
        case .heatCool: "thermometer.sun.fill"
        case .auto: "arrow.triangle.2.circlepath"
        case .dry: "dehumidifier.fill"
        case .fanOnly: "fan.fill"
        case .unknown, .unavailable: "questionmark.circle"
        }
    }
}

// MARK: - ReadOnlyTemperatureArc

private struct ReadOnlyTemperatureArc: View {
    var currentTemperature: Double?
    var range: ClosedRange<Double>
    var tintColor: Color
    var temperatureFormatter: (Double) -> String

    private static let startAngle: Double = 135
    private static let endAngle: Double = 405
    private static let sweepAngle: Double = 270
    private static let trackWidth: CGFloat = 20
    private static let markerRadius: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let arcRadius = (size - Self.trackWidth - Self.markerRadius * 2) / 2

            ZStack {
                Path { path in
                    path.addArc(
                        center: center,
                        radius: arcRadius,
                        startAngle: .degrees(Self.startAngle),
                        endAngle: .degrees(Self.endAngle),
                        clockwise: false
                    )
                }
                .stroke(tintColor.opacity(0.3), style: StrokeStyle(lineWidth: Self.trackWidth, lineCap: .round))

                if let current = currentTemperature,
                   current >= range.lowerBound && current <= range.upperBound {
                    let fraction = (current - range.lowerBound) / (range.upperBound - range.lowerBound)
                    let angle = Self.startAngle + min(max(fraction, 0), 1) * Self.sweepAngle
                    let radians = angle * Double.pi / 180
                    let point = CGPoint(
                        x: center.x + arcRadius * Foundation.cos(radians),
                        y: center.y + arcRadius * Foundation.sin(radians)
                    )
                    Circle()
                        .fill(Color(PlatformColor.systemGray2))
                        .frame(width: Self.markerRadius * 2, height: Self.markerRadius * 2)
                        .position(point)
                }

                if let current = currentTemperature {
                    Text(temperatureFormatter(current))
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .contentTransition(.numericText())
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Localization

private extension ClimateControlPanel {
    enum Localization {
        static let preset = String(localized: "Preset", comment: "Label for the preset mode picker in the climate control panel")
        static let fanMode = String(localized: "Fan", comment: "Label for the fan mode picker in the climate control panel")
        static let swingMode = String(localized: "Swing", comment: "Label for the swing mode picker in the climate control panel")
    }
}
