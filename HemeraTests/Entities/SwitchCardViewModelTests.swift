import Foundation
import Mortar
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct SwitchCardViewModelTests {

    // MARK: - Icon Name

    @Test
    func iconName_outlet() {
        let vm = makeViewModel(deviceClass: .outlet, state: .off)
        #expect(vm.iconName == "powerplug.fill")
    }

    @Test
    func iconName_switch() {
        let vm = makeViewModel(deviceClass: .switch, state: .off)
        #expect(vm.iconName == "power")
    }

    @Test
    func iconName_withMappedIcon_usesMapping() {
        let entity = SwitchEntity(entityId: "switch.test", name: "Test", state: .on, deviceClass: .outlet, icon: "mdi:fan")
        let vm = SwitchCardViewModel(switchEntity: entity, controller: SpySwitchControlling())
        #expect(vm.iconName == "fan.fill")
    }

    @Test
    func iconName_withUnmappedIcon_fallsBackToDeviceClass() {
        let entity = SwitchEntity(entityId: "switch.test", name: "Test", state: .on, deviceClass: .outlet, icon: "mdi:nonexistent-xyz")
        let vm = SwitchCardViewModel(switchEntity: entity, controller: SpySwitchControlling())
        #expect(vm.iconName == "powerplug.fill")
    }

    // MARK: - On State Colors

    @Test
    func onState_colors() {
        let vm = makeViewModel(deviceClass: .switch, state: .on)
        #expect(vm.iconBackgroundColor == .green)
        #expect(vm.tintColor == .green)
    }

    // MARK: - Off State Colors

    @Test
    func offState_colors() {
        let vm = makeViewModel(deviceClass: .switch, state: .off)
        #expect(vm.iconBackgroundColor == PlatformColor.systemGray3)
        #expect(vm.tintColor == .green)
    }

    // MARK: - isOn

    @Test
    func isOn_whenStateOn_returnsTrue() {
        let vm = makeViewModel(deviceClass: .switch, state: .on)
        #expect(vm.isOn == true)
    }

    @Test
    func isOn_whenStateOff_returnsFalse() {
        let vm = makeViewModel(deviceClass: .switch, state: .off)
        #expect(vm.isOn == false)
    }

    // MARK: - Toggle

    @Test
    func toggle_whenOn_callsControllerWithFalse() async {
        let spy = SpySwitchControlling()
        let vm = makeViewModel(deviceClass: .switch, state: .on, controller: spy)

        vm.toggle()

        await vm.controllerTask?.value
        #expect(spy.calledIds == ["switch.test"])
        #expect(spy.calledOnValues == [false])
    }

    @Test
    func toggle_whenOff_callsControllerWithTrue() async {
        let spy = SpySwitchControlling()
        let vm = makeViewModel(deviceClass: .switch, state: .off, controller: spy)

        vm.toggle()

        await vm.controllerTask?.value
        #expect(spy.calledIds == ["switch.test"])
        #expect(spy.calledOnValues == [true])
    }

    // MARK: - setOn

    @Test
    func setOn_true_callsControllerWithTrue() async {
        let spy = SpySwitchControlling()
        let vm = makeViewModel(deviceClass: .outlet, state: .off, controller: spy)

        vm.setOn(true)

        await vm.controllerTask?.value
        #expect(spy.calledIds == ["switch.test"])
        #expect(spy.calledOnValues == [true])
    }

    @Test
    func setOn_false_callsControllerWithFalse() async {
        let spy = SpySwitchControlling()
        let vm = makeViewModel(deviceClass: .outlet, state: .on, controller: spy)

        vm.setOn(false)

        await vm.controllerTask?.value
        #expect(spy.calledIds == ["switch.test"])
        #expect(spy.calledOnValues == [false])
    }

    // MARK: - Device Class

    @Test
    func deviceClass_outlet() {
        let vm = makeViewModel(deviceClass: .outlet, state: .off)
        #expect(vm.deviceClass == .outlet)
    }

    @Test
    func deviceClass_switch() {
        let vm = makeViewModel(deviceClass: .switch, state: .off)
        #expect(vm.deviceClass == .switch)
    }

    // MARK: - Has Overlay

    @Test
    func hasOverlay_isTrue() {
        let vm = makeViewModel(deviceClass: .outlet, state: .on)
        #expect(vm.hasOverlay)
        #expect(vm.makeOverlayView(isPresented: .constant(true)) != nil)
    }

    // MARK: - Helpers

    private func makeViewModel(
        deviceClass: SwitchEntity.DeviceClass,
        state: SwitchEntity.State
    ) -> SwitchCardViewModel {
        makeViewModel(deviceClass: deviceClass, state: state, controller: SpySwitchControlling())
    }

    private func makeViewModel(
        deviceClass: SwitchEntity.DeviceClass,
        state: SwitchEntity.State,
        controller: SwitchControlling
    ) -> SwitchCardViewModel {
        let entity = SwitchEntity(entityId: "switch.test", name: "Test", state: state, deviceClass: deviceClass)
        return SwitchCardViewModel(switchEntity: entity, controller: controller)
    }
}

@MainActor
private final class SpySwitchControlling: SwitchControlling {
    var calledIds: [String] = []
    var calledOnValues: [Bool] = []

    func setSwitch(_ id: String, on: Bool) async {
        calledIds.append(id)
        calledOnValues.append(on)
    }
}
