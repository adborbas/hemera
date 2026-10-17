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

    // MARK: - Has Overlay

    @Test
    func hasOverlay_isFalse() {
        let vm = makeViewModel()
        #expect(vm.hasOverlay == false)
        #expect(vm.makeOverlayView(isPresented: .constant(true)) == nil)
    }

    // MARK: - Helpers

    private func makeViewModel(icon: String? = nil, controller: SceneControlling? = nil) -> SceneCardViewModel {
        let scene = SceneEntity(entityId: "scene.test", name: "Test", icon: icon)
        return SceneCardViewModel(scene: scene, controller: controller ?? StubSceneControlling(), iconResolver: IconTranslationsFixture.resolver())
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
