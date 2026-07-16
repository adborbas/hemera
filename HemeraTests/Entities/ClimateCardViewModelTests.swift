import Foundation
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct ClimateCardViewModelTests {

    // MARK: - Icon Name (by HVAC Action)

    @Test func iconName_actionOff() {
        let vm = makeViewModel(hvacAction: .off)
        #expect(vm.iconName == "power")
    }

    @Test func iconName_actionHeating() {
        let vm = makeViewModel(hvacAction: .heating)
        #expect(vm.iconName == "heat.waves")
    }

    @Test func iconName_actionPreheating() {
        let vm = makeViewModel(hvacAction: .preheating)
        #expect(vm.iconName == "heat.waves")
    }

    @Test func iconName_actionCooling() {
        let vm = makeViewModel(hvacAction: .cooling)
        #expect(vm.iconName == "snowflake")
    }

    @Test func iconName_actionDrying() {
        let vm = makeViewModel(hvacAction: .drying)
        #expect(vm.iconName == "dehumidifier.fill")
    }

    @Test func iconName_actionFan() {
        let vm = makeViewModel(hvacAction: .fan)
        #expect(vm.iconName == "fan.fill")
    }

    @Test func iconName_actionIdle_usesModesIcon() {
        let vm = makeViewModel(state: .heat, hvacAction: .idle)
        #expect(vm.iconName == "heat.waves")
    }

    @Test func iconName_actionDefrosting() {
        let vm = makeViewModel(hvacAction: .defrosting)
        #expect(vm.iconName == "snowflake.slash")
    }

    // MARK: - Icon Name (Fallback to Mode)

    @Test func iconName_noAction_modeHeat() {
        let vm = makeViewModel(state: .heat)
        #expect(vm.iconName == "heat.waves")
    }

    @Test func iconName_noAction_modeCool() {
        let vm = makeViewModel(state: .cool)
        #expect(vm.iconName == "snowflake")
    }

    @Test func iconName_noAction_modeOff() {
        let vm = makeViewModel(state: .off)
        #expect(vm.iconName == "power")
    }

    @Test func iconName_noAction_modeHeatCool() {
        let vm = makeViewModel(state: .heatCool)
        #expect(vm.iconName == "thermometer.medium")
    }

    @Test func iconName_noAction_modeDry() {
        let vm = makeViewModel(state: .dry)
        #expect(vm.iconName == "dehumidifier.fill")
    }

    @Test func iconName_noAction_modeFanOnly() {
        let vm = makeViewModel(state: .fanOnly)
        #expect(vm.iconName == "fan.fill")
    }

    // MARK: - Active State

    @Test func isActive_whenOff_isFalse() {
        let vm = makeViewModel(state: .off)
        #expect(vm.isActive == false)
    }

    @Test func isActive_whenHeat_isTrue() {
        let vm = makeViewModel(state: .heat)
        #expect(vm.isActive == true)
    }

    @Test func isActive_whenCool_isTrue() {
        let vm = makeViewModel(state: .cool)
        #expect(vm.isActive == true)
    }

    @Test func isActive_whenUnknown_isFalse() {
        let vm = makeViewModel(state: .unknown)
        #expect(vm.isActive == false)
    }

    // MARK: - Status Text

    @Test func statusText_withActionAndTemp_showsActionName() {
        let vm = makeViewModel(state: .heat, hvacAction: .heating, currentTemperature: 21.5)
        #expect(vm.statusText.contains("Heating"))
        #expect(vm.statusText.contains("21.5"))
        #expect(vm.statusText.contains("\u{00B7}"))
    }

    @Test func statusText_withActionIdle_showsIdle() {
        let vm = makeViewModel(state: .auto, hvacAction: .idle, currentTemperature: 21)
        #expect(vm.statusText.contains("Idle"))
    }

    @Test func statusText_noAction_showsModeName() {
        let vm = makeViewModel(state: .heat, currentTemperature: 19.8)
        #expect(vm.statusText.contains("Heat"))
        #expect(!vm.statusText.contains("Heating"))
    }

    @Test func statusText_withWholeCurrentTemp() {
        let vm = makeViewModel(state: .heat, currentTemperature: 22)
        #expect(vm.statusText.contains("22\u{00B0}"))
    }

    @Test func statusText_withoutCurrentTemp() {
        let vm = makeViewModel(state: .cool)
        #expect(!vm.statusText.contains("\u{00B7}"))
    }

    // MARK: - Feature Support

    @Test func supportsTargetTemperature_withFeature() {
        let vm = makeViewModel(features: .targetTemperature)
        #expect(vm.supportsTargetTemperature == true)
    }

    @Test func supportsTargetTemperature_withoutFeature() {
        let vm = makeViewModel(features: [])
        #expect(vm.supportsTargetTemperature == false)
    }

    @Test func supportsTemperatureRange_withFeature() {
        let vm = makeViewModel(features: .targetTemperatureRange)
        #expect(vm.supportsTemperatureRange == true)
    }

    @Test func supportsHumidity_withFeature() {
        let vm = makeViewModel(features: .targetHumidity)
        #expect(vm.supportsHumidity == true)
    }

    @Test func supportsFanMode_withFeatureAndModes() {
        let vm = makeViewModel(features: .fanMode, fanModesRaw: ["auto", "low", "high"])
        #expect(vm.supportsFanMode == true)
    }

    @Test func supportsFanMode_withFeatureButNoModes() {
        let vm = makeViewModel(features: .fanMode, fanModesRaw: [])
        #expect(vm.supportsFanMode == false)
    }

    @Test func supportsFanMode_withoutFeature() {
        let vm = makeViewModel(features: [], fanModesRaw: ["auto", "low"])
        #expect(vm.supportsFanMode == false)
    }

    @Test func supportsSwingMode_withFeatureAndModes() {
        let vm = makeViewModel(features: .swingMode, swingModesRaw: ["off", "vertical"])
        #expect(vm.supportsSwingMode == true)
    }

    @Test func supportsPresetMode_withFeatureAndModes() {
        let vm = makeViewModel(features: .presetMode, presetModesRaw: ["eco", "comfort"])
        #expect(vm.supportsPresetMode == true)
    }

    // MARK: - Range Mode

    @Test func isRangeMode_heatCoolWithRangeFeature() {
        let vm = makeViewModel(state: .heatCool, features: .targetTemperatureRange)
        #expect(vm.isRangeMode == true)
    }

    @Test func isRangeMode_heatWithRangeFeature_isFalse() {
        let vm = makeViewModel(state: .heat, features: .targetTemperatureRange)
        #expect(vm.isRangeMode == false)
    }

    @Test func isRangeMode_heatCoolWithoutRangeFeature_isFalse() {
        let vm = makeViewModel(state: .heatCool, features: [])
        #expect(vm.isRangeMode == false)
    }

    // MARK: - Actions

    @Test func togglePower_whenOff_callsTurnOn() async {
        let spy = SpyClimateControlling()
        let vm = makeViewModel(state: .off, controller: spy)

        vm.togglePower()
        await vm.actionTask?.value

        #expect(spy.turnOnCalls == ["climate.test"])
    }

    @Test func togglePower_whenOn_callsTurnOff() async {
        let spy = SpyClimateControlling()
        let vm = makeViewModel(state: .heat, controller: spy)

        vm.togglePower()
        await vm.actionTask?.value

        #expect(spy.turnOffCalls == ["climate.test"])
    }

    @Test func setTemperature_callsController() async {
        let spy = SpyClimateControlling()
        let vm = makeViewModel(state: .heat, controller: spy)

        vm.setTemperature(22.5)
        await vm.actionTask?.value

        #expect(spy.setTemperatureCalls.count == 1)
        #expect(spy.setTemperatureCalls.first?.temperature == 22.5)
    }

    @Test func setHVACMode_callsController() async {
        let spy = SpyClimateControlling()
        let vm = makeViewModel(state: .off, controller: spy)

        vm.setHVACMode(.cool)
        await vm.actionTask?.value

        #expect(spy.setHVACModeCalls.count == 1)
        #expect(spy.setHVACModeCalls.first?.mode == "cool")
    }

    @Test func setTemperatureRange_callsController() async {
        let spy = SpyClimateControlling()
        let vm = makeViewModel(state: .heatCool, features: .targetTemperatureRange, controller: spy)

        vm.setTemperatureRange(low: 18, high: 24)
        await vm.actionTask?.value

        #expect(spy.setTemperatureRangeCalls.count == 1)
        #expect(spy.setTemperatureRangeCalls.first?.low == 18)
        #expect(spy.setTemperatureRangeCalls.first?.high == 24)
    }

    @Test func setFanMode_callsController() async {
        let spy = SpyClimateControlling()
        let vm = makeViewModel(state: .cool, controller: spy)

        vm.setFanMode("high")
        await vm.actionTask?.value

        #expect(spy.setFanModeCalls.count == 1)
        #expect(spy.setFanModeCalls.first?.id == "climate.test")
        #expect(spy.setFanModeCalls.first?.mode == "high")
    }

    @Test func togglePower_whenUnavailable_doesNotCallController() async {
        let spy = SpyClimateControlling()
        let vm = makeViewModel(state: .off, isAvailable: false, controller: spy)

        vm.togglePower()
        // actionTask is nil when unavailable
        #expect(spy.turnOnCalls.isEmpty)
        #expect(spy.turnOffCalls.isEmpty)
    }

    @Test func setTemperature_whenUnavailable_doesNotCallController() async {
        let spy = SpyClimateControlling()
        let vm = makeViewModel(state: .heat, isAvailable: false, controller: spy)

        vm.setTemperature(22)
        #expect(spy.setTemperatureCalls.isEmpty)
    }

    // MARK: - Available HVAC Modes

    @Test func availableHVACModes_parsesFromRaw() {
        let vm = makeViewModel(hvacModesRaw: ["off", "heat", "cool", "fan_only"])
        #expect(vm.availableHVACModes == [.off, .heat, .cool, .fanOnly])
    }

    @Test func availableHVACModes_skipsInvalidValues() {
        let vm = makeViewModel(hvacModesRaw: ["off", "invalid", "heat"])
        #expect(vm.availableHVACModes == [.off, .heat])
    }

    // MARK: - Target Temperature Cooldown

    @Test
    func targetTemperature_whileSuppressed_returnsPending_thenModelAfterExpiry() async {
        let cooldown = CommitCooldown(duration: 0.05)
        let climate = ClimateEntity(
            entityId: "climate.test",
            name: "Test Climate",
            state: .heat,
            temperature: 20,
            hvacModesRaw: ["off", "heat"],
            supportedFeaturesRaw: ClimateEntity.SupportedFeatures.targetTemperature.rawValue
        )
        let vm = ClimateCardViewModel(climate: climate, controller: SpyClimateControlling(), cooldown: cooldown)

        #expect(vm.targetTemperature == 20)

        // Commit a new target; the model is unchanged (server has not confirmed).
        vm.setTemperature(24)
        #expect(vm.targetTemperature == 24)

        /**
         No state_changed arrives (failed commit): after the window the value
         must reconcile back to the model (server truth). Await the expiry task
         directly so scheduler contention can't flake the result.
         */
        await cooldown.expiryTask?.value
        #expect(vm.targetTemperature == 20)
    }

    // MARK: - Helpers

    private func makeViewModel(
        state: ClimateEntity.HVACMode = .off,
        hvacAction: ClimateEntity.HVACAction? = nil,
        currentTemperature: Double? = nil,
        temperature: Double? = nil,
        features: ClimateEntity.SupportedFeatures = [],
        hvacModesRaw: [String] = ["off", "heat"],
        fanModesRaw: [String]? = nil,
        swingModesRaw: [String]? = nil,
        presetModesRaw: [String]? = nil,
        isAvailable: Bool = true,
        controller: ClimateControlling? = nil
    ) -> ClimateCardViewModel {
        let climate = ClimateEntity(
            entityId: "climate.test",
            name: "Test Climate",
            state: state,
            hvacAction: hvacAction,
            currentTemperature: currentTemperature,
            temperature: temperature,
            hvacModesRaw: hvacModesRaw,
            fanModesRaw: fanModesRaw,
            swingModesRaw: swingModesRaw,
            presetModesRaw: presetModesRaw,
            supportedFeaturesRaw: features.rawValue
        )
        climate.isAvailable = isAvailable
        return ClimateCardViewModel(
            climate: climate,
            controller: controller ?? SpyClimateControlling()
        )
    }
}

@MainActor
private final class SpyClimateControlling: ClimateControlling {
    var setHVACModeCalls: [(id: String, mode: String)] = []
    var setTemperatureCalls: [(id: String, temperature: Double)] = []
    var setTemperatureRangeCalls: [(id: String, low: Double, high: Double)] = []
    var setFanModeCalls: [(id: String, mode: String)] = []
    var setSwingModeCalls: [(id: String, mode: String)] = []
    var setPresetModeCalls: [(id: String, mode: String)] = []
    var setHumidityCalls: [(id: String, humidity: Double)] = []
    var turnOnCalls: [String] = []
    var turnOffCalls: [String] = []

    func setHVACMode(_ id: String, mode: String) async {
        setHVACModeCalls.append((id, mode))
    }

    func setTemperature(_ id: String, temperature: Double) async {
        setTemperatureCalls.append((id, temperature))
    }

    func setTemperatureRange(_ id: String, low: Double, high: Double) async {
        setTemperatureRangeCalls.append((id, low, high))
    }

    func setFanMode(_ id: String, mode: String) async {
        setFanModeCalls.append((id, mode))
    }

    func setSwingMode(_ id: String, mode: String) async {
        setSwingModeCalls.append((id, mode))
    }

    func setPresetMode(_ id: String, mode: String) async {
        setPresetModeCalls.append((id, mode))
    }

    func setHumidity(_ id: String, humidity: Double) async {
        setHumidityCalls.append((id, humidity))
    }

    func turnOnClimate(_ id: String) async {
        turnOnCalls.append(id)
    }

    func turnOffClimate(_ id: String) async {
        turnOffCalls.append(id)
    }
}
