import Foundation
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct ButtonCardViewModelTests {

    // MARK: - Icon Name

    @Test
    func iconName_restart() {
        let vm = makeViewModel(deviceClass: .restart)
        #expect(vm.iconName == "arrow.clockwise.circle.fill")
    }

    @Test
    func iconName_update() {
        let vm = makeViewModel(deviceClass: .update)
        #expect(vm.iconName == "arrow.down.circle.fill")
    }

    @Test
    func iconName_unknown() {
        let vm = makeViewModel(deviceClass: .unknown)
        #expect(vm.iconName == "button.horizontal.top.press")
    }

    @Test
    func iconName_withMappedIcon_usesMapping() {
        let button = ButtonEntity(entityId: "button.test", name: "Test", deviceClass: .restart, icon: "mdi:wifi")
        let vm = ButtonCardViewModel(button: button, controller: SpyButtonControlling())
        #expect(vm.iconName == "wifi")
    }

    @Test
    func iconName_withUnmappedIcon_fallsBackToDeviceClass() {
        let button = ButtonEntity(entityId: "button.test", name: "Test", deviceClass: .update, icon: "mdi:nonexistent-xyz")
        let vm = ButtonCardViewModel(button: button, controller: SpyButtonControlling())
        #expect(vm.iconName == "arrow.down.circle.fill")
    }

    // MARK: - Icon Background Color

    @Test
    func iconBackgroundColor_restart_isOrange() {
        let vm = makeViewModel(deviceClass: .restart)
        #expect(vm.iconBackgroundColor == .orange)
    }

    @Test
    func iconBackgroundColor_update_isGreen() {
        let vm = makeViewModel(deviceClass: .update)
        #expect(vm.iconBackgroundColor == .green)
    }

    // MARK: - Subtitle

    @Test
    func subtitle_restart() {
        let vm = makeViewModel(deviceClass: .restart)
        #expect(vm.subtitle == "Restart")
    }

    @Test
    func subtitle_update() {
        let vm = makeViewModel(deviceClass: .update)
        #expect(vm.subtitle == "Update")
    }

    @Test
    func subtitle_unknown() {
        let vm = makeViewModel(deviceClass: .unknown)
        #expect(vm.subtitle == "Press")
    }

    // MARK: - Requires Confirmation

    @Test
    func requiresConfirmation_restart_isTrue() {
        let vm = makeViewModel(deviceClass: .restart)
        #expect(vm.requiresConfirmation == true)
    }

    @Test
    func requiresConfirmation_update_isTrue() {
        let vm = makeViewModel(deviceClass: .update)
        #expect(vm.requiresConfirmation == true)
    }

    @Test
    func requiresConfirmation_identify_isFalse() {
        let vm = makeViewModel(deviceClass: .identify)
        #expect(vm.requiresConfirmation == false)
    }

    @Test
    func requiresConfirmation_unknown_isFalse() {
        let vm = makeViewModel(deviceClass: .unknown)
        #expect(vm.requiresConfirmation == false)
    }

    // MARK: - Press

    @Test
    func press_callsControllerWithEntityId() async {
        let mock = SpyButtonControlling()
        let button = ButtonEntity(entityId: "button.test_press", name: "Test", deviceClass: .restart)
        let vm = ButtonCardViewModel(button: button, controller: mock)

        vm.press()

        await vm.controllerTask?.value
        #expect(mock.pressedIds == ["button.test_press"])
    }

    // MARK: - Helpers

    private func makeViewModel(deviceClass: ButtonEntity.DeviceClass) -> ButtonCardViewModel {
        let button = ButtonEntity(entityId: "button.test", name: "Test", deviceClass: deviceClass)
        return ButtonCardViewModel(button: button, controller: SpyButtonControlling())
    }
}

@MainActor
private final class SpyButtonControlling: ButtonControlling {
    var pressedIds: [String] = []

    func pressButton(_ id: String) async {
        pressedIds.append(id)
    }
}
