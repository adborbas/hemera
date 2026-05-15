import Foundation
import Mortar
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct LightCardViewModelTests {

    // MARK: - On State

    @Test
    func onState_properties() {
        let vm = makeViewModel(state: .on)
        #expect(vm.iconName == "lightbulb.fill")
        #expect(vm.iconBackgroundColor == .yellow)
        #expect(vm.tintColor == .yellow)
    }

    // MARK: - Off State

    @Test
    func offState_properties() {
        let vm = makeViewModel(state: .off)
        #expect(vm.iconName == "lightbulb.fill")
        #expect(vm.iconBackgroundColor == PlatformColor.systemGray3)
        #expect(vm.tintColor == .yellow)
    }

    // MARK: - HA Icon Override

    @Test
    func iconName_withMappedIcon_usesMapping() {
        let light = LightEntity(entityId: "light.test", name: "Test", state: .on, icon: "mdi:ceiling-light")
        let vm = LightCardViewModel(light: light, controller: StubLightControlling())
        #expect(vm.iconName == "chandelier.fill")
    }

    @Test
    func iconName_withUnmappedIcon_fallsBackToDefault() {
        let light = LightEntity(entityId: "light.test", name: "Test", state: .on, icon: "mdi:nonexistent-xyz")
        let vm = LightCardViewModel(light: light, controller: StubLightControlling())
        #expect(vm.iconName == "lightbulb.fill")
    }

    // MARK: - Helpers

    private func makeViewModel(state: LightEntity.State) -> LightCardViewModel {
        let light = LightEntity(entityId: "light.test", name: "Test", state: state)
        return LightCardViewModel(light: light, controller: StubLightControlling())
    }
}

@MainActor
private final class StubLightControlling: LightControlling {
    func setLight(_ id: String, on: Bool) async {}
    func setBrightness(_ id: String, to brightness: Int) async {}
    func setColorTemp(_ id: String, to mireds: Int) async {}
    func setHSColor(_ id: String, hue: Double, saturation: Double) async {}
}
