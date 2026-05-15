import Foundation
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct CoverCardViewModelTests {

    // MARK: - Feature Support

    @Test
    func supportsOpen_withOpenFeature_isTrue() {
        let vm = makeViewModel(features: [.open])
        #expect(vm.supportsOpen == true)
    }

    @Test
    func supportsOpen_withoutOpenFeature_isFalse() {
        let vm = makeViewModel(features: [])
        #expect(vm.supportsOpen == false)
    }

    @Test
    func supportsClose_withCloseFeature_isTrue() {
        let vm = makeViewModel(features: [.close])
        #expect(vm.supportsClose == true)
    }

    @Test
    func supportsStop_withStopFeature_isTrue() {
        let vm = makeViewModel(features: [.stop])
        #expect(vm.supportsStop == true)
    }

    // MARK: - Supported Control Modes

    @Test
    func supportedControlModes_withAllFeatures_returnsBothModes() {
        let vm = makeViewModel(features: [.open, .close, .stop, .setPosition])
        #expect(vm.supportedControlModes == [.slider, .buttons])
    }

    @Test
    func supportedControlModes_withOnlySetPosition_returnsOnlySlider() {
        let vm = makeViewModel(features: [.setPosition])
        #expect(vm.supportedControlModes == [.slider])
    }

    @Test
    func supportedControlModes_withOnlyOpenClose_returnsOnlyButtons() {
        let vm = makeViewModel(features: [.open, .close])
        #expect(vm.supportedControlModes == [.buttons])
    }

    @Test
    func supportedControlModes_withOnlyStop_returnsOnlyButtons() {
        let vm = makeViewModel(features: [.stop])
        #expect(vm.supportedControlModes == [.buttons])
    }

    @Test
    func supportedControlModes_withNoFeatures_returnsEmpty() {
        let vm = makeViewModel(features: [])
        #expect(vm.supportedControlModes.isEmpty)
    }

    // MARK: - Preferred Control Mode

    @Test
    func preferredControlMode_defaultIsNil() {
        let vm = makeViewModel(features: [.open, .close, .stop, .setPosition])
        #expect(vm.preferredControlMode == nil)
    }

    @Test
    func preferredControlMode_roundtrip() {
        let vm = makeViewModel(features: [.open, .close, .stop, .setPosition])
        vm.preferredControlMode = .buttons
        #expect(vm.preferredControlMode == .buttons)

        vm.preferredControlMode = .slider
        #expect(vm.preferredControlMode == .slider)

        vm.preferredControlMode = nil
        #expect(vm.preferredControlMode == nil)
    }

    // MARK: - Actions

    @Test
    func open_callsController() async {
        let spy = SpyCoverControlling()
        let vm = makeViewModel(features: [.open], controller: spy)

        vm.open()
        await vm.actionTask?.value

        #expect(spy.openedIds == ["cover.test"])
    }

    @Test
    func close_callsController() async {
        let spy = SpyCoverControlling()
        let vm = makeViewModel(features: [.close], controller: spy)

        vm.close()
        await vm.actionTask?.value

        #expect(spy.closedIds == ["cover.test"])
    }

    @Test
    func stop_callsController() async {
        let spy = SpyCoverControlling()
        let vm = makeViewModel(features: [.stop], controller: spy)

        vm.stop()
        await vm.actionTask?.value

        #expect(spy.stoppedIds == ["cover.test"])
    }

    @Test
    func open_whenUnavailable_doesNotCallController() async {
        let spy = SpyCoverControlling()
        let vm = makeViewModel(features: [.open], isAvailable: false, controller: spy)

        vm.open()
        await vm.actionTask?.value

        #expect(spy.openedIds.isEmpty)
    }

    // MARK: - Simple State Description

    @Test
    func simpleStateDescription_open() {
        let vm = makeViewModel(state: .open)
        #expect(vm.simpleStateDescription == String(localized: "Open"))
    }

    @Test
    func simpleStateDescription_closed() {
        let vm = makeViewModel(state: .closed)
        #expect(vm.simpleStateDescription == String(localized: "Closed"))
    }

    @Test
    func simpleStateDescription_opening() {
        let vm = makeViewModel(state: .opening)
        #expect(vm.simpleStateDescription == String(localized: "Opening"))
    }

    @Test
    func simpleStateDescription_closing() {
        let vm = makeViewModel(state: .closing)
        #expect(vm.simpleStateDescription == String(localized: "Closing"))
    }

    @Test
    func simpleStateDescription_unknown() {
        let vm = makeViewModel(state: .unknown)
        #expect(vm.simpleStateDescription == String(localized: "Unknown"))
    }

    @Test
    func simpleStateDescription_unavailable() {
        let vm = makeViewModel(state: .unavailable)
        #expect(vm.simpleStateDescription == String(localized: "Unavailable"))
    }

    @Test
    func simpleStateDescription_openWithPosition_doesNotIncludePosition() {
        let vm = makeViewModel(state: .open, position: 75)
        #expect(vm.simpleStateDescription == String(localized: "Open"))
    }

    // MARK: - isOpen

    @Test
    func isOpen_open_isTrue() {
        let vm = makeViewModel(state: .open)
        #expect(vm.isOpen == true)
    }

    @Test
    func isOpen_opening_isTrue() {
        let vm = makeViewModel(state: .opening)
        #expect(vm.isOpen == true)
    }

    @Test
    func isOpen_closing_isTrue() {
        let vm = makeViewModel(state: .closing)
        #expect(vm.isOpen == true)
    }

    @Test
    func isOpen_closed_isFalse() {
        let vm = makeViewModel(state: .closed)
        #expect(vm.isOpen == false)
    }

    @Test
    func isOpen_unknown_isFalse() {
        let vm = makeViewModel(state: .unknown)
        #expect(vm.isOpen == false)
    }

    @Test
    func isOpen_unavailable_isFalse() {
        let vm = makeViewModel(state: .unavailable)
        #expect(vm.isOpen == false)
    }

    // MARK: - Tint Color

    @Test
    func tintColor_isBlue() {
        let vm = makeViewModel()
        #expect(vm.tintColor == .blue)
    }

    // MARK: - Helpers

    private func makeViewModel(
        state: CoverEntity.State = .closed,
        position: Int? = nil,
        features: CoverEntity.Features = [],
        isAvailable: Bool = true,
        controller: CoverControlling? = nil
    ) -> CoverCardViewModel {
        let cover = CoverEntity(
            entityId: "cover.test",
            name: "Test Cover",
            state: state,
            currentPosition: position,
            supportedFeaturesRaw: features.rawValue
        )
        cover.isAvailable = isAvailable
        return CoverCardViewModel(cover: cover, controller: controller ?? SpyCoverControlling())
    }
}

@MainActor
private final class SpyCoverControlling: CoverControlling {
    var openedIds: [String] = []
    var closedIds: [String] = []
    var stoppedIds: [String] = []
    var positionCalls: [(id: String, position: Int)] = []
    var toggledIds: [String] = []

    func setPosition(of id: String, to position: Int) async {
        positionCalls.append((id, position))
    }

    func openCover(_ id: String) async {
        openedIds.append(id)
    }

    func closeCover(_ id: String) async {
        closedIds.append(id)
    }

    func stopCover(_ id: String) async {
        stoppedIds.append(id)
    }

    func toggleCover(_ id: String) async {
        toggledIds.append(id)
    }
}
