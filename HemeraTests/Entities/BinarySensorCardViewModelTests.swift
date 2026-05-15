import Foundation
import Mortar
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct BinarySensorCardViewModelTests {

    // MARK: - Tint Color

    @Test
    func tintColor_smoke_isRed() {
        let vm = makeViewModel(deviceClass: .smoke, state: .on)
        #expect(vm.tintColor == .red)
    }

    @Test
    func tintColor_nonSmoke_isTeal() {
        let vm = makeViewModel(deviceClass: .motion, state: .on)
        #expect(vm.tintColor == .teal)
    }

    // MARK: - Icon Background Color

    @Test
    func iconBackgroundColor_onSmoke_isRed() {
        let vm = makeViewModel(deviceClass: .smoke, state: .on)
        #expect(vm.iconBackgroundColor == .red)
    }

    @Test
    func iconBackgroundColor_onMotion_isTeal() {
        let vm = makeViewModel(deviceClass: .motion, state: .on)
        #expect(vm.iconBackgroundColor == .teal)
    }

    @Test
    func iconBackgroundColor_off_isSystemGray3() {
        let vm = makeViewModel(deviceClass: .motion, state: .off)
        #expect(vm.iconBackgroundColor == PlatformColor.systemGray3)
    }

    @Test
    func iconBackgroundColor_unknown_isSystemGray3() {
        let vm = makeViewModel(deviceClass: .door, state: .unknown)
        #expect(vm.iconBackgroundColor == PlatformColor.systemGray3)
    }

    // MARK: - Icon Name

    @Test
    func iconName_motionOn() {
        let vm = makeViewModel(deviceClass: .motion, state: .on)
        #expect(vm.iconName == "figure.walk")
    }

    @Test
    func iconName_motionOff() {
        let vm = makeViewModel(deviceClass: .motion, state: .off)
        #expect(vm.iconName == "figure.stand")
    }

    @Test
    func iconName_doorOn() {
        let vm = makeViewModel(deviceClass: .door, state: .on)
        #expect(vm.iconName == "door.left.hand.open")
    }

    @Test
    func iconName_doorOff() {
        let vm = makeViewModel(deviceClass: .door, state: .off)
        #expect(vm.iconName == "door.left.hand.closed")
    }

    @Test
    func iconName_smokeOn() {
        let vm = makeViewModel(deviceClass: .smoke, state: .on)
        #expect(vm.iconName == "smoke.fill")
    }

    @Test
    func iconName_unknown_showsQuestionmark() {
        let vm = makeViewModel(deviceClass: .motion, state: .unknown)
        #expect(vm.iconName == "questionmark.circle")
    }

    @Test
    func iconName_unavailable_showsExclamation() {
        let vm = makeViewModel(deviceClass: .motion, state: .unavailable)
        #expect(vm.iconName == "exclamationmark.circle")
    }

    // MARK: - State Description

    @Test
    func stateDescription_motionOn_isDetected() {
        let vm = makeViewModel(deviceClass: .motion, state: .on)
        #expect(vm.stateDescription == "Detected")
    }

    @Test
    func stateDescription_doorOn_isOpen() {
        let vm = makeViewModel(deviceClass: .door, state: .on)
        #expect(vm.stateDescription == "Open")
    }

    @Test
    func stateDescription_doorOff_isClosed() {
        let vm = makeViewModel(deviceClass: .door, state: .off)
        #expect(vm.stateDescription == "Closed")
    }

    @Test
    func stateDescription_occupancyOn_isOccupied() {
        let vm = makeViewModel(deviceClass: .occupancy, state: .on)
        #expect(vm.stateDescription == "Occupied")
    }

    // MARK: - isOn

    @Test
    func isOn_stateOn_isTrue() {
        let vm = makeViewModel(deviceClass: .motion, state: .on)
        #expect(vm.isOn == true)
    }

    @Test
    func isOn_stateOff_isFalse() {
        let vm = makeViewModel(deviceClass: .motion, state: .off)
        #expect(vm.isOn == false)
    }

    // MARK: - Helpers

    private func makeViewModel(
        deviceClass: BinarySensorEntity.DeviceClass,
        state: BinarySensorEntity.State
    ) -> BinarySensorCardViewModel {
        let entity = BinarySensorEntity(
            entityId: "binary_sensor.test",
            name: "Test",
            state: state,
            deviceClass: deviceClass
        )
        return BinarySensorCardViewModel(binarySensor: entity)
    }
}
