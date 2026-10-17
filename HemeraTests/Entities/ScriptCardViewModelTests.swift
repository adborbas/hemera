import Foundation
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct ScriptCardViewModelTests {

    // MARK: - Icon Name

    @Test
    func iconName_withNilIcon_usesDefault() {
        let vm = makeViewModel()
        #expect(vm.iconName == "script-text")
    }

    @Test
    func iconName_withEntityIconOverride_usesItVerbatim() {
        let vm = makeViewModel(icon: "mdi:timer")
        #expect(vm.iconName == "timer")
    }

    @Test
    func iconName_withUnsupportedIconPack_fallsBackToDefault() {
        let vm = makeViewModel(icon: "phu:something")
        #expect(vm.iconName == "script-text")
    }

    // MARK: - Running State

    @Test
    func isRunning_reflectsEntityState() {
        #expect(makeViewModel(state: .off).isRunning == false)
        #expect(makeViewModel(state: .on).isRunning == true)
    }

    // MARK: - Primary Action

    @Test
    func performPrimaryAction_whenIdle_runsScript() async {
        let spy = SpyScriptControlling()
        let vm = makeViewModel(state: .off, controller: spy)

        vm.performPrimaryAction()
        // Allow the Task inside run() to run
        try? await Task.sleep(for: .milliseconds(100))

        #expect(spy.ranIds == ["script.test"])
        #expect(spy.cancelledIds.isEmpty)
    }

    @Test
    func performPrimaryAction_whenRunning_cancelsScript() async {
        let spy = SpyScriptControlling()
        let vm = makeViewModel(state: .on, controller: spy)

        vm.performPrimaryAction()
        // Allow the Task inside cancel() to run
        try? await Task.sleep(for: .milliseconds(100))

        #expect(spy.cancelledIds == ["script.test"])
        #expect(spy.ranIds.isEmpty)
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
        state: ScriptEntity.State = .off,
        controller: ScriptControlling? = nil
    ) -> ScriptCardViewModel {
        let script = ScriptEntity(entityId: "script.test", name: "Test", state: state, icon: icon)
        return ScriptCardViewModel(script: script, controller: controller ?? StubScriptControlling(), iconResolver: IconTranslationsFixture.resolver())
    }
}

@MainActor
private final class StubScriptControlling: ScriptControlling {
    func runScript(_ id: String) async {}
    func cancelScript(_ id: String) async {}
}

@MainActor
private final class SpyScriptControlling: ScriptControlling {
    var ranIds: [String] = []
    var cancelledIds: [String] = []
    func runScript(_ id: String) async {
        ranIds.append(id)
    }
    func cancelScript(_ id: String) async {
        cancelledIds.append(id)
    }
}
