import Foundation
import HemeraLog
import Mortar
import SwiftData
import SwiftUI

// MARK: - Light Control Mode

enum LightControlMode: Hashable {
    case brightness
    case colorTemp
    case hue

    var iconName: String {
        switch self {
        case .brightness: "sun.max.fill"
        case .colorTemp: "thermometer.medium"
        case .hue: "paintpalette.fill"
        }
    }
}

// MARK: - View Model

@Observable
@MainActor
final class LightCardViewModel: Identifiable {
    private(set) var light: LightEntity

    private var pendingBrightness: Int?
    private var pendingColorTemp: Int?
    private var pendingHSColor: [Double]?

    var brightness: Int {
        if cooldown.isSuppressed, let pending = pendingBrightness { return pending }
        return light.brightness ?? 0
    }

    var colorTemp: Int? {
        if cooldown.isSuppressed, let pending = pendingColorTemp { return pending }
        return light.colorTemp
    }

    var hsColor: [Double]? {
        if cooldown.isSuppressed, let pending = pendingHSColor { return pending }
        return light.hsColor
    }
    var colorMode: String? { light.colorMode }
    var minMireds: Int? { light.minMireds }
    var maxMireds: Int? { light.maxMireds }

    var supportedModes: [LightControlMode] {
        guard let modes = light.supportedColorModes else { return [.brightness] }
        // A light whose only color mode is "onoff" has no brightness/color controls.
        if Set(modes) == ["onoff"] { return [] }
        var result: [LightControlMode] = [.brightness]
        if modes.contains("color_temp") {
            if light.minMireds != nil && light.maxMireds != nil {
                result.append(.colorTemp)
            } else {
                Log.warning("Light \(id) supports color_temp but is missing min_mireds/max_mireds — color temp control disabled")
            }
        }
        let hueModes: Set<String> = ["hs", "xy", "rgb", "rgbw", "rgbww"]
        if !hueModes.isDisjoint(with: modes) {
            result.append(.hue)
        }
        return result
    }

    /// Whether the light exposes a brightness control (i.e. is dimmable).
    /// `false` for on/off-only lights, which drive neither the fill nor the overlay.
    var isDimmable: Bool { supportedModes.contains(.brightness) }

    nonisolated let id: String
    var name: String { light.name }
    var isOn: Bool { light.isOn }
    var isAvailable: Bool { light.isAvailable }
    var deviceId: String? { light.deviceId }

    var iconName: String {
        if let icon = light.icon,
           let sfSymbol = MDISymbolMapper.entitySFSymbol(for: icon) {
            return sfSymbol
        }
        return "lightbulb.fill"
    }

    var iconBackgroundColor: Color {
        isOn ? .yellow : PlatformColor.systemGray3
    }

    var tintColor: Color { .yellow }

    private let cooldown: CommitCooldown
    private let controller: LightControlling

    init(light: LightEntity, controller: LightControlling, cooldown: CommitCooldown? = nil) {
        self.cooldown = cooldown ?? CommitCooldown()
        self.id = light.entityId
        self.light = light
        self.controller = controller
    }

    func toggle() {
        guard light.isAvailable else { return }
        Task {
            await controller.setLight(id, on: !isOn)
        }
    }

    func setBrightness(to value: Int) {
        guard light.isAvailable else { return }
        resetPending()
        pendingBrightness = value
        cooldown.commit()
        Task {
            await controller.setBrightness(id, to: value)
        }
    }

    func setColorTemp(to mireds: Int) {
        guard light.isAvailable else { return }
        resetPending()
        pendingColorTemp = mireds
        cooldown.commit()
        Task {
            await controller.setColorTemp(id, to: mireds)
        }
    }

    func setHSColor(hue: Double, saturation: Double) {
        guard light.isAvailable else { return }
        resetPending()
        pendingHSColor = [hue, saturation]
        cooldown.commit()
        Task {
            await controller.setHSColor(id, hue: hue, saturation: saturation)
        }
    }

    /**
     One cooldown gates all three pending values, so every commit clears the
     others first — otherwise a stale pending from an earlier commit would
     resurface (and mask server truth) when a different property is committed
     within the shared window.
     */
    private func resetPending() {
        pendingBrightness = nil
        pendingColorTemp = nil
        pendingHSColor = nil
    }
}

// MARK: - Factory Registration

extension LightCardViewModel {
    static func registration(controller: LightControlling) -> ViewModelFactory.Registration {
        ViewModelFactory.Registration(
            makeViewModelsForArea: { area in
                area.lights.sorted(by: { $0.entityId < $1.entityId }).map {
                    LightCardViewModel(light: $0, controller: controller)
                }
            },
            makeViewModelForEntityId: { entityId, context in
                guard let light = LightEntity.fetch(byId: entityId, in: context) else { return nil }
                return LightCardViewModel(light: light, controller: controller)
            }
        )
    }
}

// MARK: - EntityCardViewModel

extension LightCardViewModel: EntityCardViewModel {
    func makeCardView() -> AnyView {
        AnyView(LightCard(viewModel: self))
    }

    /// On/off-only lights have no controllable modes, so they present no overlay —
    /// the card icon toggle is their only control. Keep in sync with `makeOverlayView`.
    var hasOverlay: Bool { !supportedModes.isEmpty }

    func makeOverlayView(isPresented: Binding<Bool>) -> AnyView? {
        guard hasOverlay else { return nil }
        return AnyView(LightControlPanel(viewModel: self, isPresented: isPresented))
    }
}
