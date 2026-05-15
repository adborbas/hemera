import Foundation
import Mortar
import SwiftData
import SwiftUI

@Observable
@MainActor
final class ClimateCardViewModel: Identifiable {
    private(set) var climate: ClimateEntity

    nonisolated let id: String
    var name: String { climate.name }
    var isAvailable: Bool { climate.isAvailable }
    var deviceId: String? { climate.deviceId }

    private let cooldown: CommitCooldown
    private let controller: ClimateControlling
    private(set) var actionTask: Task<Void, Never>?

    // MARK: - HVAC State

    var hvacMode: ClimateEntity.HVACMode { climate.state }
    var hvacAction: ClimateEntity.HVACAction? { climate.hvacAction }

    var isActive: Bool {
        switch climate.state {
        case .off, .unknown, .unavailable: false
        default: true
        }
    }

    // MARK: - Temperature

    private var pendingTargetTemp: Double?
    private var pendingTargetTempLow: Double?
    private var pendingTargetTempHigh: Double?

    var currentTemperature: Double? { climate.currentTemperature }

    var targetTemperature: Double? {
        if cooldown.isSuppressed, let pending = pendingTargetTemp { return pending }
        return climate.temperature
    }

    var targetTempHigh: Double? {
        if cooldown.isSuppressed, let pending = pendingTargetTempHigh { return pending }
        return climate.targetTempHigh
    }

    var targetTempLow: Double? {
        if cooldown.isSuppressed, let pending = pendingTargetTempLow { return pending }
        return climate.targetTempLow
    }
    var minTemp: Double { climate.minTemp }
    var maxTemp: Double { climate.maxTemp }
    var targetTempStep: Double { climate.targetTempStep }

    // MARK: - Humidity

    var currentHumidity: Double? { climate.currentHumidity }
    var targetHumidity: Double? { climate.humidity }
    var minHumidity: Double { climate.minHumidity }
    var maxHumidity: Double { climate.maxHumidity }

    // MARK: - Modes

    var availableHVACModes: [ClimateEntity.HVACMode] {
        climate.hvacModesRaw.compactMap { ClimateEntity.HVACMode(rawValue: $0) }
    }

    var fanModes: [String]? { climate.fanModesRaw }
    var swingModes: [String]? { climate.swingModesRaw }
    var presetModes: [String]? { climate.presetModesRaw }
    var currentFanMode: String? { climate.fanMode }
    var currentSwingMode: String? { climate.swingMode }
    var currentPresetMode: String? { climate.presetMode }

    // MARK: - Feature Support

    var supportedFeatures: ClimateEntity.SupportedFeatures { climate.supportedFeatures }

    var supportsTargetTemperature: Bool {
        supportedFeatures.contains(.targetTemperature)
    }

    var supportsTemperatureRange: Bool {
        supportedFeatures.contains(.targetTemperatureRange)
    }

    var isOff: Bool { hvacMode == .off }

    var showsTargetControl: Bool {
        guard !isOff else { return false }
        if isRangeMode {
            return targetTempLow != nil && targetTempHigh != nil
        }
        return supportsTargetTemperature && targetTemperature != nil
    }

    var isRangeMode: Bool {
        supportsTemperatureRange && (hvacMode == .heatCool || hvacMode == .auto)
    }

    var supportsHumidity: Bool {
        supportedFeatures.contains(.targetHumidity)
    }

    var supportsFanMode: Bool {
        supportedFeatures.contains(.fanMode) && !(climate.fanModesRaw ?? []).isEmpty
    }

    var supportsSwingMode: Bool {
        supportedFeatures.contains(.swingMode) && !(climate.swingModesRaw ?? []).isEmpty
    }

    var supportsPresetMode: Bool {
        supportedFeatures.contains(.presetMode) && !(climate.presetModesRaw ?? []).isEmpty
    }

    // MARK: - Visual Properties

    static let warmColor: Color = .warm
    static let coolColor: Color = .cool

    var iconName: String {
        if let action = hvacAction {
            return iconForAction(action)
        }
        return iconForMode(hvacMode)
    }

    var iconBackgroundColor: Color {
        guard isActive else { return PlatformColor.systemGray3 }
        guard let action = hvacAction else { return colorForMode(hvacMode) }
        return colorForAction(action)
    }

    var tintColor: Color {
        guard isActive else { return PlatformColor.systemGray3 }
        guard let action = hvacAction else { return colorForMode(hvacMode) }
        return colorForAction(action)
    }

    var arcGradientColors: [Color]? {
        guard isRangeMode else { return nil }
        switch hvacMode {
        case .heatCool, .auto:
            return [Self.warmColor, Self.warmColor, Self.coolColor, Self.coolColor]
        default:
            return nil
        }
    }

    var lowHandleColor: Color? {
        guard isRangeMode else { return nil }
        switch hvacMode {
        case .heatCool, .auto: return Self.warmColor
        default: return nil
        }
    }

    var highHandleColor: Color? {
        guard isRangeMode else { return nil }
        switch hvacMode {
        case .heatCool, .auto: return Self.coolColor
        default: return nil
        }
    }

    var statusLabel: String {
        if let action = hvacAction {
            return localizedActionName(action)
        }
        return localizedModeName(hvacMode)
    }

    var statusText: String {
        if let current = currentTemperature {
            return "\(statusLabel) \u{00B7} \(Self.formatTemperature(current))"
        }
        return statusLabel
    }

    // MARK: - Init

    init(climate: ClimateEntity, controller: ClimateControlling, cooldown: CommitCooldown? = nil) {
        self.cooldown = cooldown ?? CommitCooldown()
        self.id = climate.entityId
        self.climate = climate
        self.controller = controller
    }

    // MARK: - Display Helpers

    func displayName(for mode: ClimateEntity.HVACMode) -> String {
        localizedModeName(mode)
    }

    // MARK: - Actions

    func togglePower() {
        guard climate.isAvailable else { return }
        if climate.state == .off {
            actionTask = Task { await controller.turnOnClimate(id) }
        } else {
            actionTask = Task { await controller.turnOffClimate(id) }
        }
    }

    func setHVACMode(_ mode: ClimateEntity.HVACMode) {
        guard climate.isAvailable else { return }
        actionTask = Task { await controller.setHVACMode(id, mode: mode.rawValue) }
    }

    func setTemperature(_ temperature: Double) {
        guard climate.isAvailable else { return }
        pendingTargetTemp = temperature
        cooldown.commit()
        actionTask = Task { await controller.setTemperature(id, temperature: temperature) }
    }

    func setTemperatureRange(low: Double, high: Double) {
        guard climate.isAvailable else { return }
        pendingTargetTempLow = low
        pendingTargetTempHigh = high
        cooldown.commit()
        actionTask = Task { await controller.setTemperatureRange(id, low: low, high: high) }
    }

    func setFanMode(_ mode: String) {
        guard climate.isAvailable else { return }
        actionTask = Task { await controller.setFanMode(id, mode: mode) }
    }

    func setSwingMode(_ mode: String) {
        guard climate.isAvailable else { return }
        actionTask = Task { await controller.setSwingMode(id, mode: mode) }
    }

    func setPresetMode(_ mode: String) {
        guard climate.isAvailable else { return }
        actionTask = Task { await controller.setPresetMode(id, mode: mode) }
    }

    func setHumidity(_ humidity: Double) {
        guard climate.isAvailable else { return }
        actionTask = Task { await controller.setHumidity(id, humidity: humidity) }
    }

    // MARK: - Temperature Formatting

    static func formatTemperature(_ temp: Double) -> String {
        if temp == temp.rounded() {
            return "\(Int(temp))\u{00B0}"
        }
        return String(format: "%.1f\u{00B0}", temp)
    }

}

// MARK: - Icon & Color Helpers

extension ClimateCardViewModel {
    private func iconForAction(_ action: ClimateEntity.HVACAction) -> String {
        switch action {
        case .off: "power"
        case .preheating, .heating: "heat.waves"
        case .cooling: "snowflake"
        case .drying: "dehumidifier.fill"
        case .fan: "fan.fill"
        case .idle: iconForMode(hvacMode)
        case .defrosting: "snowflake.slash"
        }
    }

    private func iconForMode(_ mode: ClimateEntity.HVACMode) -> String {
        switch mode {
        case .off: "power"
        case .heat: "heat.waves"
        case .cool: "snowflake"
        case .heatCool, .auto: "thermometer.medium"
        case .dry: "dehumidifier.fill"
        case .fanOnly: "fan.fill"
        case .unknown, .unavailable: "questionmark.circle"
        }
    }

    private func colorForAction(_ action: ClimateEntity.HVACAction) -> Color {
        switch action {
        case .off, .idle: PlatformColor.systemGray3
        case .preheating, .heating: Self.warmColor
        case .cooling, .defrosting: Self.coolColor
        case .drying: .teal
        case .fan: .cyan
        }
    }

    private func colorForMode(_ mode: ClimateEntity.HVACMode) -> Color {
        switch mode {
        case .off, .unknown, .unavailable: PlatformColor.systemGray3
        case .heat: Self.warmColor
        case .cool: Self.coolColor
        case .heatCool, .auto: .green
        case .dry: .teal
        case .fanOnly: .cyan
        }
    }

    private func localizedActionName(_ action: ClimateEntity.HVACAction) -> String {
        switch action {
        case .off: Localization.off
        case .preheating: Localization.actionPreheating
        case .heating: Localization.actionHeating
        case .cooling: Localization.actionCooling
        case .drying: Localization.actionDrying
        case .idle: Localization.actionIdle
        case .fan: Localization.actionFan
        case .defrosting: Localization.actionDefrosting
        }
    }

    private func localizedModeName(_ mode: ClimateEntity.HVACMode) -> String {
        switch mode {
        case .off: Localization.off
        case .heat: Localization.modeHeat
        case .cool: Localization.modeCool
        case .heatCool: Localization.modeHeatCool
        case .auto: Localization.modeAuto
        case .dry: Localization.modeDry
        case .fanOnly: Localization.modeFanOnly
        case .unknown: Localization.unknown
        case .unavailable: Localization.unavailable
        }
    }
}

// MARK: - Factory Registration

extension ClimateCardViewModel {
    static func registration(controller: ClimateControlling) -> ViewModelFactory.Registration {
        ViewModelFactory.Registration(
            makeViewModelsForArea: { area in
                area.climates.sorted(by: { $0.entityId < $1.entityId }).map {
                    ClimateCardViewModel(climate: $0, controller: controller)
                }
            },
            makeViewModelForEntityId: { entityId, context in
                guard let climate = ClimateEntity.fetch(byId: entityId, in: context) else { return nil }
                return ClimateCardViewModel(climate: climate, controller: controller)
            }
        )
    }
}

// MARK: - EntityCardViewModel

extension ClimateCardViewModel: EntityCardViewModel {
    func makeCardView() -> AnyView {
        AnyView(ClimateCard(viewModel: self))
    }

    func makeOverlayView(isPresented: Binding<Bool>) -> AnyView? {
        AnyView(ClimateControlPanel(viewModel: self, isPresented: isPresented))
    }
}

// MARK: - Localization

private extension ClimateCardViewModel {
    enum Localization {
        // Shared
        static let off = String(localized: "Off", comment: "Climate state shown on card when the system is off")
        static let unknown = String(localized: "Unknown", comment: "Climate state shown on card when the state cannot be determined")
        static let unavailable = String(localized: "Unavailable", comment: "Climate state shown on card when the device is unreachable")

        // HVAC Actions (what the system is currently doing)
        static let actionHeating = String(localized: "Heating", comment: "Climate action shown on card when the system is actively heating")
        static let actionPreheating = String(localized: "Preheating", comment: "Climate action shown on card when the system is preheating")
        static let actionCooling = String(localized: "Cooling", comment: "Climate action shown on card when the system is actively cooling")
        static let actionDrying = String(localized: "Drying", comment: "Climate action shown on card when the system is actively dehumidifying")
        static let actionIdle = String(localized: "Idle", comment: "Climate action shown on card when the system is on but not actively working")
        static let actionFan = String(localized: "Fan", comment: "Climate action shown on card when only the fan is running")
        static let actionDefrosting = String(localized: "Defrosting", comment: "Climate action shown on card when the system is defrosting")

        // HVAC Modes (fallback when action is not reported)
        static let modeHeat = String(localized: "Heat", comment: "Climate mode shown on card when set to heat mode and no action is reported")
        static let modeCool = String(localized: "Cool", comment: "Climate mode shown on card when set to cool mode and no action is reported")
        static let modeHeatCool = String(localized: "Heat/Cool", comment: "Climate mode shown on card when in heat_cool (dual setpoint) mode")
        static let modeAuto = String(localized: "Auto", comment: "Climate mode shown on card when in auto mode")
        static let modeDry = String(localized: "Dry", comment: "Climate mode shown on card when set to dry mode and no action is reported")
        static let modeFanOnly = String(localized: "Fan", comment: "Climate mode shown on card when in fan only mode")
    }
}
