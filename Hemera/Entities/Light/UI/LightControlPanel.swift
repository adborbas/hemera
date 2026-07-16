import SwiftUI
import Mortar

struct LightControlPanel: View {
    var viewModel: LightCardViewModel
    @Binding var isPresented: Bool

    @State private var currentMode: LightControlMode = .brightness
    @State private var brightness: Double = 0
    @State private var colorTemp: Double = 326
    @State private var hue: Double = 180
    @State private var saturation: Double = 100

    private var supportedModes: [LightControlMode] {
        viewModel.supportedModes
    }

    // MARK: - Subtitle

    private var subtitle: String {
        guard viewModel.isOn else { return Localization.off }
        switch currentMode {
        case .brightness:
            let percent = Int(round(brightness / 255.0 * 100))
            return "\(percent)%"
        case .colorTemp:
            let kelvin = Int(1_000_000 / colorTemp)
            return "\(kelvin)K"
        case .hue:
            return "\(Int(hue))\u{00B0}"
        }
    }

    // MARK: - Body

    var body: some View {
        EntityControlPanel(
            isPresented: $isPresented,
            title: viewModel.name,
            subtitle: subtitle
        ) {
            slider
        } footer: {
            PillPicker(
                options: supportedModes,
                selection: $currentMode,
                icon: { $0.iconName }
            )
            .opacity(supportedModes.count > 1 ? 1 : 0)
            .allowsHitTesting(supportedModes.count > 1)
        }
        .animation(Mortar.Motion.springBouncy, value: currentMode)
        .onAppear { syncFromEntity() }
        .onChange(of: viewModel.brightness) { _, _ in syncBrightness() }
        .onChange(of: viewModel.colorTemp) { _, _ in syncColorTemp() }
        .onChange(of: viewModel.hsColor) { _, _ in syncHSColor() }
        .onChange(of: supportedModes) { _, newModes in
            if !newModes.contains(currentMode), let first = newModes.first {
                currentMode = first
            }
        }
    }

    // MARK: - Brightness fill color

    private var brightnessColor: Color {
        switch viewModel.colorMode {
        case "hs", "xy", "rgb", "rgbw", "rgbww":
            Color(hue: hue / 360, saturation: saturation / 100.0, brightness: 1)
        default:
            colorTempToColor(mireds: colorTemp)
        }
    }

    // MARK: - Slider

    @ViewBuilder
    private var slider: some View {
        switch currentMode {
        case .brightness:
            VerticalSlider(
                value: $brightness,
                configuration: .init(range: 0...255, style: .fill(.bottom))
            ) { value in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.setBrightness(to: Int(value))
            }
            .sliderFill(brightnessColor)
            .frame(width: Mortar.ControlPanelSize.controlWidth)
            .transition(.blurReplace)

        case .colorTemp:
            let minMireds = viewModel.minMireds ?? 153
            let maxMireds = viewModel.maxMireds ?? 500
            // Sort and widen a degenerate span so ClosedRange never traps and the slider
            // geometry divisors stay finite for a misconfigured server.
            let lo = Double(Swift.min(minMireds, maxMireds))
            let hi = Double(Swift.max(minMireds, maxMireds))
            let miredsRange = lo < hi ? lo...hi : lo...(lo + 1)
            VerticalSlider(
                value: $colorTemp,
                configuration: .init(
                    range: miredsRange,
                    style: .picker
                )
            ) { value in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.setColorTemp(to: Int(value))
            }
            .pickerFill(
                colors: LightColorTemperature.gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: Mortar.ControlPanelSize.controlWidth)
            .transition(.blurReplace)

        case .hue:
            VerticalSlider(
                value: $hue,
                configuration: .init(range: 0...360, style: .picker)
            ) { value in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.setHSColor(hue: value, saturation: saturation)
            }
            .pickerFill(
                colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(width: Mortar.ControlPanelSize.controlWidth)
            .transition(.blurReplace)
        }
    }

    // MARK: - Sync helpers

    private func syncFromEntity() {
        brightness = Double(viewModel.brightness)

        if let ct = viewModel.colorTemp {
            colorTemp = Double(ct)
        } else if let min = viewModel.minMireds, let max = viewModel.maxMireds {
            colorTemp = Double(min + max) / 2.0
        }

        if let hs = viewModel.hsColor, hs.count >= 2 {
            hue = hs[0]
            saturation = hs[1]
        }
    }

    private func syncBrightness() {
        brightness = Double(viewModel.brightness)
    }

    private func syncColorTemp() {
        if let ct = viewModel.colorTemp {
            colorTemp = Double(ct)
        }
    }

    private func syncHSColor() {
        if let hs = viewModel.hsColor, hs.count >= 2 {
            hue = hs[0]
            saturation = hs[1]
        }
    }

    // MARK: - Color conversion

    private func colorTempToColor(mireds: Double) -> Color {
        guard let min = viewModel.minMireds, let max = viewModel.maxMireds else {
            return Color(red: 1.0, green: 0.85, blue: 0.6)
        }
        // t: 0 = coolest (low mireds), 1 = warmest (high mireds)
        let lo = Swift.min(min, max)
        let hi = Swift.max(min, max)
        let span = Double(hi - lo)
        let t = span > 0 ? (mireds - Double(lo)) / span : 0
        // Cool end (~6500K): visible cool blue
        // Warm end (~2000K): amber
        let r = 0.82 + t * 0.18
        let g = 0.88 - t * 0.30
        let b = 1.0 - t * 0.84
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Localization

private extension LightControlPanel {
    enum Localization {
        static let off = String(localized: "Off", comment: "Light brightness label shown in the overlay when the light is turned off")
    }
}
