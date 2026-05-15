import Foundation
import Testing
@testable import Hemera

@MainActor
struct SceneCardViewModelTests {

    // MARK: - Icon Name

    @Test
    func iconName_withNilIcon_usesDefault() {
        let vm = makeViewModel()
        #expect(vm.iconName == "play.circle.fill")
    }

    @Test
    func iconName_withMappedIcon_usesMapping() {
        let vm = makeViewModel(icon: "mdi:timer")
        #expect(vm.iconName == "timer")
    }

    @Test
    func iconName_withUnmappedIcon_fallsBackToDefault() {
        let vm = makeViewModel(icon: "mdi:nonexistent-xyz")
        #expect(vm.iconName == "play.circle.fill")
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

    // MARK: - Helpers

    private func makeViewModel(icon: String? = nil, controller: SceneControlling? = nil) -> SceneCardViewModel {
        let scene = SceneEntity(entityId: "scene.test", name: "Test", icon: icon)
        return SceneCardViewModel(scene: scene, controller: controller ?? StubSceneControlling())
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
