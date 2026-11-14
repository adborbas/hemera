import Foundation
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct SceneCardViewModelTests {

    // MARK: - Icon Name

    @Test
    func iconName_withNilIcon_usesDefault() {
        let vm = makeViewModel()
        #expect(vm.iconName == "palette")
    }

    @Test
    func iconName_withEntityIconOverride_usesItVerbatim() {
        let vm = makeViewModel(icon: "mdi:timer")
        #expect(vm.iconName == "timer")
    }

    @Test
    func iconName_withUnsupportedIconPack_fallsBackToDefault() {
        let vm = makeViewModel(icon: "phu:something")
        #expect(vm.iconName == "palette")
    }

    // MARK: - Primary Action

    @Test
    func performPrimaryAction_activatesScene() async {
        let spy = SpySceneControlling()
        let vm = makeViewModel(controller: spy)

        vm.performPrimaryAction()
        // Allow the Task inside activate() to run
        try? await Task.sleep(for: .milliseconds(100))

        #expect(spy.activatedIds == ["scene.test"])
    }

    // MARK: - Activation Confirmation

    /// Card taps, icon taps and the welcome loop all go through activate(), so all of them must confirm.
    @Test
    func performPrimaryAction_confirmsActivation_thenClears() async {
        let vm = makeViewModel(confirmationDuration: .milliseconds(50))

        vm.performPrimaryAction()
        #expect(vm.isConfirmingActivation)

        for _ in 0..<40 where vm.isConfirmingActivation {
            try? await Task.sleep(for: .milliseconds(50))
        }
        #expect(!vm.isConfirmingActivation)
    }

    @Test
    func activate_unavailableScene_doesNotConfirm() {
        let vm = makeViewModel()
        vm.scene.isAvailable = false

        vm.activate()

        #expect(!vm.isConfirmingActivation)
    }

    @Test
    func activate_twice_keepsConfirmingFromTheLatestTap() async {
        // The first tick ends at 2 s, the second's at 3.2 s; the 2.4 s check has slack both ways.
        let vm = makeViewModel(confirmationDuration: .seconds(2))

        vm.activate()
        try? await Task.sleep(for: .milliseconds(1200))
        vm.activate()
        try? await Task.sleep(for: .milliseconds(1200))

        #expect(vm.isConfirmingActivation)
    }

    // MARK: - Has Overlay

    @Test
    func hasOverlay_isFalse() {
        let vm = makeViewModel()
        #expect(vm.hasOverlay == false)
        #expect(vm.makeOverlayView(isPresented: .constant(true)) == nil)
    }

    // MARK: - Helpers

    private func makeViewModel(
        icon: String? = nil,
        controller: SceneControlling? = nil,
        confirmationDuration: Duration = .seconds(1)
    ) -> SceneCardViewModel {
        let scene = SceneEntity(entityId: "scene.test", name: "Test", icon: icon)
        return SceneCardViewModel(
            scene: scene,
            controller: controller ?? StubSceneControlling(),
            iconResolver: IconTranslationsFixture.resolver(),
            confirmationDuration: confirmationDuration
        )
    }
}

@MainActor
private final class StubSceneControlling: SceneControlling {
    func activateScene(_ id: String) async {}
}

@MainActor
private final class SpySceneControlling: SceneControlling {
    var activatedIds: [String] = []
    func activateScene(_ id: String) async {
        activatedIds.append(id)
    }
}
