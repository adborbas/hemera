import Foundation
import Mortar
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct AutomationCardViewModelTests {

    // MARK: - On State

    @Test
    func onState_properties() {
        let vm = makeViewModel(state: .on)
        #expect(vm.iconName == "robot")
        #expect(vm.iconBackgroundColor == .orange)
        #expect(vm.tintColor == .orange)
    }

    // MARK: - Off State

    @Test
    func offState_properties() {
        let vm = makeViewModel(state: .off)
        #expect(vm.iconName == "robot-off")
        #expect(vm.iconBackgroundColor == PlatformColor.systemGray3)
        #expect(vm.tintColor == .orange)
    }

    // MARK: - HA Icon Override

    @Test
    func iconName_withEntityIconOverride_usesItVerbatim() {
        let automation = AutomationEntity(
            entityId: "automation.test",
            name: "Test",
            state: .on,
            icon: "mdi:lightbulb"
        )
        let vm = AutomationCardViewModel(automation: automation, controller: StubAutomationControlling(), iconResolver: IconTranslationsFixture.resolver())
        #expect(vm.iconName == "lightbulb")
    }

    @Test
    func iconName_withUnsupportedIconPack_fallsBackToDefault() {
        let automation = AutomationEntity(
            entityId: "automation.test",
            name: "Test",
            state: .on,
            icon: "phu:gears"
        )
        let vm = AutomationCardViewModel(automation: automation, controller: StubAutomationControlling(), iconResolver: IconTranslationsFixture.resolver())
        #expect(vm.iconName == "robot")
    }

    // MARK: - Has Overlay

    @Test
    func hasOverlay_isTrue() {
        let vm = makeViewModel(state: .on)
        #expect(vm.hasOverlay)
        #expect(vm.makeOverlayView(isPresented: .constant(true)) != nil)
    }

    // MARK: - Helpers

    private func makeViewModel(state: AutomationEntity.State) -> AutomationCardViewModel {
        let automation = AutomationEntity(
            entityId: "automation.test",
            name: "Test",
            state: state,
            lastTriggered: nil
        )
        return AutomationCardViewModel(automation: automation, controller: StubAutomationControlling(), iconResolver: IconTranslationsFixture.resolver())
    }
}

@MainActor
private final class StubAutomationControlling: AutomationControlling {
    func setAutomation(_ id: String, on: Bool) async {}
    func triggerAutomation(_ id: String) async {}
}
