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

    // MARK: - Brightness Cooldown

    @Test
    func brightness_whileSuppressed_returnsPending_thenModelAfterExpiry() async throws {
        let cooldown = CommitCooldown(duration: 0.1)
        let light = LightEntity(entityId: "light.test", name: "Test", state: .on, brightness: 100)
        let vm = LightCardViewModel(light: light, controller: StubLightControlling(), cooldown: cooldown)

        #expect(vm.brightness == 100)

        // Commit a new value; the model is unchanged (server has not confirmed).
        vm.setBrightness(to: 200)
        #expect(vm.brightness == 200)

        /**
         No state_changed arrives (failed commit): after the window the slider
         value must reconcile back to the model (server truth).
         */
        try await Task.sleep(for: .milliseconds(250))
        #expect(vm.brightness == 100)
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
