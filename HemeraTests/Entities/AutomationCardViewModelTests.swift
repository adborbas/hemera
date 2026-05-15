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
        #expect(vm.iconName == "gearshape.2.fill")
        #expect(vm.iconBackgroundColor == .orange)
        #expect(vm.tintColor == .orange)
    }

    // MARK: - Off State

    @Test
    func offState_properties() {
        let vm = makeViewModel(state: .off)
        #expect(vm.iconName == "gearshape.2.fill")
        #expect(vm.iconBackgroundColor == PlatformColor.systemGray3)
        #expect(vm.tintColor == .orange)
    }

    // MARK: - HA Icon Override

    @Test
    func iconName_withMappedIcon_usesMapping() {
        let automation = AutomationEntity(
            entityId: "automation.test",
            name: "Test",
            state: .on,
            icon: "mdi:lightbulb"
        )
        let vm = AutomationCardViewModel(automation: automation, controller: StubAutomationControlling())
        #expect(vm.iconName == "lightbulb.fill")
    }

    @Test
    func iconName_withUnmappedIcon_fallsBackToDefault() {
        let automation = AutomationEntity(
            entityId: "automation.test",
            name: "Test",
            state: .on,
            icon: "mdi:nonexistent-xyz"
        )
        let vm = AutomationCardViewModel(automation: automation, controller: StubAutomationControlling())
        #expect(vm.iconName == "gearshape.2.fill")
    }

    // MARK: - Helpers

    private func makeViewModel(state: AutomationEntity.State) -> AutomationCardViewModel {
        let automation = AutomationEntity(
            entityId: "automation.test",
            name: "Test",
            state: state,
            lastTriggered: nil
        )
        return AutomationCardViewModel(automation: automation, controller: StubAutomationControlling())
    }
}

@MainActor
private final class StubAutomationControlling: AutomationControlling {
    func setAutomation(_ id: String, on: Bool) async {}
    func triggerAutomation(_ id: String) async {}
}
