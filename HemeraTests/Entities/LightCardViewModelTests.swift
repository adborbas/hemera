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
    func brightness_whileSuppressed_returnsPending_thenModelAfterExpiry() async {
        let cooldown = CommitCooldown(duration: 0.05)
        let light = LightEntity(entityId: "light.test", name: "Test", state: .on, brightness: 100)
        let vm = LightCardViewModel(light: light, controller: StubLightControlling(), cooldown: cooldown)

        #expect(vm.brightness == 100)

        // Commit a new value; the model is unchanged (server has not confirmed).
        vm.setBrightness(to: 200)
        #expect(vm.brightness == 200)

        /**
         No state_changed arrives (failed commit): after the window the slider
         value must reconcile back to the model (server truth). Await the expiry
         task directly so scheduler contention can't flake the result.
         */
        await cooldown.expiryTask?.value
        #expect(vm.brightness == 100)
    }

    @Test
    func brightness_afterCommittingAnotherProperty_doesNotResurfaceStalePending() {
        // Long window so the cooldown stays suppressed for the whole test.
        let cooldown = CommitCooldown(duration: 1)
        let light = LightEntity(entityId: "light.test", name: "Test", state: .on, brightness: 100)
        let vm = LightCardViewModel(light: light, controller: StubLightControlling(), cooldown: cooldown)

        // Brightness commit that the server never confirms (model stays 100).
        vm.setBrightness(to: 200)
        #expect(vm.brightness == 200)

        // Committing a different property re-arms the shared cooldown; the stale
        // brightness pending must not resurface — brightness reflects the model.
        vm.setColorTemp(to: 250)
        #expect(vm.brightness == 100)
        #expect(vm.colorTemp == 250)
    }

    // MARK: - Supported Modes

    @Test
    func supportedModes_onoffOnly_isEmpty() {
        let vm = makeViewModel(supportedColorModes: ["onoff"])
        #expect(vm.supportedModes.isEmpty)
    }

    @Test
    func supportedModes_brightnessOnly_containsBrightness() {
        let vm = makeViewModel(supportedColorModes: ["brightness"])
        #expect(vm.supportedModes == [.brightness])
    }

    @Test
    func supportedModes_absent_defaultsToBrightness() {
        let vm = makeViewModel(supportedColorModes: nil)
        #expect(vm.supportedModes == [.brightness])
    }

    @Test
    func supportedModes_colorTempAndHue_includesAllControls() {
        let vm = makeViewModel(
            supportedColorModes: ["color_temp", "hs"],
            minMireds: 153,
            maxMireds: 500
        )
        #expect(vm.supportedModes == [.brightness, .colorTemp, .hue])
    }

    // MARK: - Is Dimmable

    @Test
    func isDimmable_onoffOnly_isFalse() {
        let vm = makeViewModel(supportedColorModes: ["onoff"])
        #expect(vm.isDimmable == false)
    }

    @Test
    func isDimmable_brightness_isTrue() {
        let vm = makeViewModel(supportedColorModes: ["brightness"])
        #expect(vm.isDimmable)
    }

    // MARK: - Has Overlay

    @Test
    func hasOverlay_onoffOnly_isFalse() {
        let vm = makeViewModel(supportedColorModes: ["onoff"])
        #expect(vm.hasOverlay == false)
        #expect(vm.makeOverlayView(isPresented: .constant(true)) == nil)
    }

    @Test
    func hasOverlay_dimmable_isTrue() {
        let vm = makeViewModel(supportedColorModes: ["brightness"])
        #expect(vm.hasOverlay)
        #expect(vm.makeOverlayView(isPresented: .constant(true)) != nil)
    }

    // MARK: - Helpers

    private func makeViewModel(state: LightEntity.State) -> LightCardViewModel {
        let light = LightEntity(entityId: "light.test", name: "Test", state: state)
        return LightCardViewModel(light: light, controller: StubLightControlling())
    }

    private func makeViewModel(
        supportedColorModes: [String]?,
        minMireds: Int? = nil,
        maxMireds: Int? = nil
    ) -> LightCardViewModel {
        let light = LightEntity(
            entityId: "light.test",
            name: "Test",
            state: .on,
            minMireds: minMireds,
            maxMireds: maxMireds,
            supportedColorModes: supportedColorModes
        )
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
