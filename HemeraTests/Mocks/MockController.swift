import Foundation
@testable import Hemera

@MainActor
final class MockController: LightControlling, CoverControlling, SceneControlling,
    SwitchControlling, ButtonControlling, AutomationControlling, ClimateControlling {
    func setLight(_ id: String, on: Bool) async {}
    func setBrightness(_ id: String, to brightness: Int) async {}
    func setColorTemp(_ id: String, to mireds: Int) async {}
    func setHSColor(_ id: String, hue: Double, saturation: Double) async {}

    func setPosition(of id: String, to position: Int) async {}
    func openCover(_ id: String) async {}
    func closeCover(_ id: String) async {}
    func stopCover(_ id: String) async {}
    func toggleCover(_ id: String) async {}

    func activateScene(_ id: String) async {}

    func setSwitch(_ id: String, on: Bool) async {}

    func pressButton(_ id: String) async {}

    func setAutomation(_ id: String, on: Bool) async {}
    func triggerAutomation(_ id: String) async {}

    func setHVACMode(_ id: String, mode: String) async {}
    func setTemperature(_ id: String, temperature: Double) async {}
    func setTemperatureRange(_ id: String, low: Double, high: Double) async {}
    func setFanMode(_ id: String, mode: String) async {}
    func setSwingMode(_ id: String, mode: String) async {}
    func setPresetMode(_ id: String, mode: String) async {}
    func setHumidity(_ id: String, humidity: Double) async {}
    func turnOnClimate(_ id: String) async {}
    func turnOffClimate(_ id: String) async {}
}
