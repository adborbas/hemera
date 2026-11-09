import Foundation
import Mortar
import SwiftData
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct VacuumCardViewModelTests {

    private static let allFeatures: VacuumEntity.Features = [.start, .pause, .stop, .returnHome, .locate]

    // MARK: - Icon tap

    @Test(arguments: [VacuumEntity.State.docked, .idle, .paused])
    func iconTapped_whenNotCleaning_startsCleaning(_ state: VacuumEntity.State) async {
        let spy = SpyVacuumControlling()
        let vm = makeViewModel(state: state, controller: spy)

        vm.iconTapped()
        await vm.actionTask?.value

        #expect(spy.calls == [.start("vacuum.robot")])
    }

    @Test
    func iconTapped_whileCleaning_pauses() async {
        let spy = SpyVacuumControlling()
        let vm = makeViewModel(state: .cleaning, controller: spy)

        vm.iconTapped()
        await vm.actionTask?.value

        #expect(spy.calls == [.pause("vacuum.robot")])
    }

    // A robot that can't pause must still be interruptible from the card.
    @Test
    func iconTapped_whileCleaningWithoutPause_stops() async {
        let spy = SpyVacuumControlling()
        let vm = makeViewModel(state: .cleaning, features: [.start, .stop], controller: spy)

        vm.iconTapped()
        await vm.actionTask?.value

        #expect(spy.calls == [.stop("vacuum.robot")])
    }

    @Test
    func iconTapped_whileCleaningWithoutPauseOrStop_doesNothing() async {
        let spy = SpyVacuumControlling()
        let vm = makeViewModel(state: .cleaning, features: [.start], controller: spy)

        vm.iconTapped()
        await vm.actionTask?.value

        #expect(spy.calls.isEmpty)
        #expect(vm.iconActionLabel == nil)
    }

    // A stray tap from the area page must never send the robot somewhere unexpected.
    @Test(arguments: [VacuumEntity.State.returning, .error, .unknown, .unavailable])
    func iconTapped_inNonActionableState_doesNothing(_ state: VacuumEntity.State) async {
        let spy = SpyVacuumControlling()
        let vm = makeViewModel(state: state, controller: spy)

        vm.iconTapped()
        await vm.actionTask?.value

        #expect(spy.calls.isEmpty)
        #expect(vm.iconActionLabel == nil)
    }

    @Test
    func iconTapped_withoutStartFeature_doesNotStart() async {
        let spy = SpyVacuumControlling()
        let vm = makeViewModel(state: .docked, features: [.pause, .stop, .returnHome], controller: spy)

        vm.iconTapped()
        await vm.actionTask?.value

        #expect(spy.calls.isEmpty)
    }

    @Test
    func iconTapped_whenRemovedFromServer_doesNothing() async {
        let spy = SpyVacuumControlling()
        let vm = makeViewModel(state: .docked, isAvailable: false, controller: spy)

        vm.iconTapped()
        await vm.actionTask?.value

        #expect(spy.calls.isEmpty)
    }

    // No optimistic UI: the card reflects only what Home Assistant reports.
    @Test
    func iconTapped_doesNotChangeStateLocally() async {
        let vm = makeViewModel(state: .docked)

        vm.iconTapped()
        await vm.actionTask?.value

        #expect(vm.state == .docked)
        #expect(vm.stateDescription == "Docked")
    }

    // MARK: - VoiceOver

    @Test
    func iconActionLabel_namesWhatTheTapDoes() {
        #expect(makeViewModel(state: .docked).iconActionLabel == "Start")
        #expect(makeViewModel(state: .cleaning).iconActionLabel == "Pause")
        #expect(makeViewModel(state: .cleaning, features: [.stop]).iconActionLabel == "Stop")
    }

    // MARK: - Appearance

    @Test
    func stateDescription_isTheLocalisedState() {
        let expected: [VacuumEntity.State: String] = [
            .cleaning: "Cleaning", .docked: "Docked", .idle: "Idle", .paused: "Paused",
            .returning: "Returning", .error: "Error", .unknown: "Unknown", .unavailable: "Unavailable"
        ]
        for state in VacuumEntity.State.allCases {
            #expect(makeViewModel(state: state).stateDescription == expected[state])
        }
    }

    // A moving robot stands out among the other cards.
    @Test(arguments: [VacuumEntity.State.cleaning, .returning])
    func appearance_whileMoving_isTintedAndWorking(_ state: VacuumEntity.State) {
        let vm = makeViewModel(state: state)

        #expect(vm.isActive)
        #expect(vm.isWorking)
        #expect(vm.tintColor == .teal)
        #expect(vm.iconBackgroundColor == .teal)
    }

    // A stuck robot stands out in red, but isn't drawn as moving.
    @Test
    func appearance_inError_isRedAndNotWorking() {
        let vm = makeViewModel(state: .error)

        #expect(vm.isActive)
        #expect(!vm.isWorking)
        #expect(vm.tintColor == .red)
        #expect(vm.iconBackgroundColor == .red)
    }

    @Test(arguments: [VacuumEntity.State.docked, .idle, .paused, .unknown, .unavailable])
    func appearance_whileStill_isGrey(_ state: VacuumEntity.State) {
        let vm = makeViewModel(state: state)

        #expect(!vm.isActive)
        #expect(!vm.isWorking)
        #expect(vm.iconBackgroundColor == PlatformColor.systemGray3)
    }

    @Test
    func iconName_usesHomeAssistantVacuumIcon() {
        #expect(makeViewModel(state: .cleaning).iconName == "robot-vacuum")
    }

    // MARK: - Robot motion

    // The panel robot only moves while the real one does, or is stuck and needs attention.
    @Test
    func robotMotion_followsTheState() {
        let expected: [VacuumEntity.State: VacuumCardViewModel.RobotMotion] = [
            .cleaning: .wander, .returning: .headingHome, .error: .errorPulse
        ]
        for state in VacuumEntity.State.allCases {
            #expect(makeViewModel(state: state).robotMotion(reduceMotion: false) == expected[state])
        }
    }

    @Test(arguments: VacuumEntity.State.allCases)
    func robotMotion_withReduceMotion_isStill(_ state: VacuumEntity.State) {
        #expect(makeViewModel(state: state).robotMotion(reduceMotion: true) == nil)
    }

    // MARK: - Panel buttons

    typealias Row = [VacuumCardViewModel.PanelButton]

    nonisolated private static func row(_ buttons: (VacuumCardViewModel.Action, Bool)...) -> Row {
        buttons.map { VacuumCardViewModel.PanelButton(action: $0.0, isEnabled: $0.1) }
    }

    // Dimmed rather than hidden, so the row keeps its layout as the robot changes state.
    @Test(arguments: [
        (VacuumEntity.State.docked, row((.start, true), (.stop, false), (.returnToBase, false), (.locate, true))),
        (.idle, row((.start, true), (.stop, false), (.returnToBase, true), (.locate, true))),
        (.paused, row((.start, true), (.stop, true), (.returnToBase, true), (.locate, true))),
        (.cleaning, row((.pause, true), (.stop, true), (.returnToBase, true), (.locate, true))),
        (.returning, row((.pause, true), (.stop, true), (.returnToBase, false), (.locate, true))),
        // A stuck robot can only be found; nothing else is suggested until the error clears.
        (.error, row((.start, false), (.stop, false), (.returnToBase, false), (.locate, true))),
        (.unknown, row((.start, false), (.stop, false), (.returnToBase, false), (.locate, false))),
        (.unavailable, row((.start, false), (.stop, false), (.returnToBase, false), (.locate, false)))
    ])
    func panelButtons_withAllFeatures_followTheStateMatrix(_ state: VacuumEntity.State, _ expected: Row) {
        #expect(makeViewModel(state: state).panelButtons == expected)
    }

    // A moving robot that can't pause must stay stoppable from the primary slot, without a second Stop.
    @Test
    func panelButtons_cleaningWithoutPause_putsStopInThePrimarySlotOnce() {
        let vm = makeViewModel(state: .cleaning, features: [.start, .stop, .returnHome, .locate])

        #expect(vm.panelButtons == Self.row((.stop, true), (.returnToBase, true), (.locate, true)))
    }

    @Test
    func panelButtons_returningWithoutPause_putsStopInThePrimarySlotOnce() {
        let vm = makeViewModel(state: .returning, features: [.start, .stop, .returnHome, .locate])

        #expect(vm.panelButtons == Self.row((.stop, true), (.returnToBase, false), (.locate, true)))
    }

    @Test
    func panelButtons_movingWithoutPauseOrStop_showsStartDimmed() {
        let vm = makeViewModel(state: .cleaning, features: [.start, .locate])

        #expect(vm.panelButtons == Self.row((.start, false), (.locate, true)))
    }

    // Never offer a button the robot can't carry out.
    @Test
    func panelButtons_hideUnsupportedActions() {
        #expect(makeViewModel(state: .paused, features: [.stop, .returnHome]).panelButtons
            == Self.row((.stop, true), (.returnToBase, true)))
        #expect(makeViewModel(state: .cleaning, features: [.pause, .locate]).panelButtons
            == Self.row((.pause, true), (.locate, true)))
        #expect(makeViewModel(state: .docked, features: []).panelButtons.isEmpty)
    }

    @Test
    func panelButtons_whenRemovedFromServer_areAllDisabled() {
        let vm = makeViewModel(state: .docked, isAvailable: false)

        #expect(vm.panelButtons.map(\.action) == [.start, .stop, .returnToBase, .locate])
        #expect(vm.panelButtons.allSatisfy { !$0.isEnabled })
    }

    @Test
    func perform_callsTheMatchingService() async {
        let spy = SpyVacuumControlling()
        let vm = makeViewModel(state: .cleaning, controller: spy)

        for action in [VacuumCardViewModel.Action.start, .pause, .stop, .returnToBase, .locate] {
            vm.perform(action)
            await vm.actionTask?.value
        }

        let id = "vacuum.robot"
        #expect(spy.calls == [.start(id), .pause(id), .stop(id), .returnToBase(id), .locate(id)])
    }

    @Test
    func action_usesHomeAssistantsIconsAndVoiceOverNames() {
        let actions: [VacuumCardViewModel.Action] = [.start, .pause, .stop, .returnToBase, .locate]

        #expect(actions.map(\.iconName)
            == ["mdi:play", "mdi:pause", "mdi:stop", "mdi:home-import-outline", "mdi:map-marker"])
        #expect(actions.map(\.label) == ["Start", "Pause", "Stop", "Return to dock", "Locate"])
    }

    // MARK: - Battery icon

    // Home Assistant frontend's `batteryLevelIcon`, so the panel shows the glyph HA does.
    @Test(arguments: [
        (0.0, "mdi:battery-alert-variant-outline", "mdi:battery-charging-outline"),
        (4, "mdi:battery-alert-variant-outline", "mdi:battery-charging-outline"),
        (5, "mdi:battery-alert-variant-outline", "mdi:battery-charging-outline"),
        (9, "mdi:battery-10", "mdi:battery-charging-outline"),
        (10, "mdi:battery-10", "mdi:battery-charging-10"),
        (14, "mdi:battery-10", "mdi:battery-charging-10"),
        (15, "mdi:battery-20", "mdi:battery-charging-20"),
        (50, "mdi:battery-50", "mdi:battery-charging-50"),
        (95, "mdi:battery", "mdi:battery-charging"),
        (100, "mdi:battery", "mdi:battery-charging")
    ])
    func batteryIcon_followsHomeAssistant(level: Double, discharging: String, charging: String) {
        #expect(VacuumCardViewModel.batteryIcon(level: level, isCharging: false) == discharging)
        #expect(VacuumCardViewModel.batteryIcon(level: level, isCharging: true) == charging)
    }

    // MARK: - Battery lookup

    @Test
    func battery_readsTheBatterySensorOnTheRobotsDevice() throws {
        let store = try BatteryStore()
        store.insert(SensorEntity(entityId: "sensor.robot_battery", name: "Battery", state: "85", deviceClass: "battery"), device: "robot")
        store.insert(SensorEntity(entityId: "sensor.phone_battery", name: "Phone", state: "20", deviceClass: "battery"), device: "phone")

        let vm = store.viewModel()

        #expect(vm.batteryLevel == 85)
        #expect(vm.batteryDescription == "85%")
        #expect(vm.batteryIconName == "mdi:battery-90")
    }

    @Test
    func battery_ignoresOtherDevicesAndOtherSensorClasses() throws {
        let store = try BatteryStore()
        store.insert(SensorEntity(entityId: "sensor.phone_battery", name: "Phone", state: "20", deviceClass: "battery"), device: "phone")
        store.insert(SensorEntity(entityId: "sensor.robot_temperature", name: "Temp", state: "21", deviceClass: "temperature"), device: "robot")

        let vm = store.viewModel()

        #expect(vm.batteryLevel == nil)
        #expect(vm.batteryIconName == nil)
        #expect(vm.batteryDescription == nil)
    }

    @Test
    func battery_whenNotANumber_hidesTheBatteryLine() throws {
        let store = try BatteryStore()
        store.insert(SensorEntity(entityId: "sensor.robot_battery", name: "Battery", state: "unavailable", deviceClass: "battery"), device: "robot")

        #expect(store.viewModel().batteryIconName == nil)
    }

    @Test
    func isCharging_readsTheChargingSensorOnTheRobotsDevice() throws {
        let store = try BatteryStore()
        store.insert(SensorEntity(entityId: "sensor.robot_battery", name: "Battery", state: "85", deviceClass: "battery"), device: "robot")
        store.insert(BinarySensorEntity(entityId: "binary_sensor.robot_charging", name: "Charging", state: .on, deviceClass: .batteryCharging), device: "robot")

        let vm = store.viewModel()

        #expect(vm.isCharging)
        #expect(vm.batteryIconName == "mdi:battery-charging-90")
    }

    @Test
    func isCharging_ignoresOtherDevicesAndAnOffSensor() throws {
        let store = try BatteryStore()
        let charging = BinarySensorEntity(entityId: "binary_sensor.robot_charging", name: "Charging", state: .off, deviceClass: .batteryCharging)
        store.insert(charging, device: "robot")
        store.insert(BinarySensorEntity(entityId: "binary_sensor.phone_charging", name: "Phone", state: .on, deviceClass: .batteryCharging), device: "phone")

        #expect(!store.viewModel().isCharging)
    }

    // The panel must redraw when Home Assistant reports a new battery level or charging state.
    @Test
    func battery_isObservable() throws {
        let store = try BatteryStore()
        let battery = SensorEntity(entityId: "sensor.robot_battery", name: "Battery", state: "85", deviceClass: "battery")
        let charging = BinarySensorEntity(entityId: "binary_sensor.robot_charging", name: "Charging", state: .off, deviceClass: .batteryCharging)
        store.insert(battery, device: "robot")
        store.insert(charging, device: "robot")
        let vm = store.viewModel()

        #expect(changes(of: { _ = vm.batteryIconName }, when: { battery.state = "40" }))
        #expect(changes(of: { _ = vm.batteryIconName }, when: { charging.state = .on }))
    }

    // MARK: - Helpers

    private func changes(of read: () -> Void, when mutate: () -> Void) -> Bool {
        nonisolated(unsafe) var changed = false
        withObservationTracking(read) { changed = true }
        mutate()
        return changed
    }

    private func makeViewModel(
        state: VacuumEntity.State,
        features: VacuumEntity.Features = allFeatures,
        isAvailable: Bool = true,
        controller: VacuumControlling? = nil
    ) -> VacuumCardViewModel {
        let vacuum = VacuumEntity(
            entityId: "vacuum.robot",
            name: "Robot",
            state: state,
            supportedFeaturesRaw: features.rawValue
        )
        vacuum.isAvailable = isAvailable
        return VacuumCardViewModel(
            vacuum: vacuum,
            controller: controller ?? SpyVacuumControlling(),
            iconResolver: IconTranslationsFixture.resolver()
        )
    }
}

@MainActor
private struct BatteryStore {
    let container: ModelContainer
    let vacuum = VacuumEntity(entityId: "vacuum.robot", name: "Robot", state: .docked)

    init() throws {
        container = try ModelContainer(
            for: VacuumEntity.self, SensorEntity.self, BinarySensorEntity.self, AreaEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        insert(vacuum, device: "robot")
    }

    func insert<Entity: StoredEntity>(_ entity: Entity, device: String) {
        entity.deviceId = device
        container.mainContext.insert(entity)
    }

    func viewModel() -> VacuumCardViewModel {
        VacuumCardViewModel(vacuum: vacuum, controller: SpyVacuumControlling())
    }
}

@MainActor
private final class SpyVacuumControlling: VacuumControlling {
    enum Call: Equatable {
        case start(String), pause(String), stop(String), returnToBase(String), locate(String)
    }

    var calls: [Call] = []

    func startVacuum(_ id: String) async { calls.append(.start(id)) }
    func pauseVacuum(_ id: String) async { calls.append(.pause(id)) }
    func stopVacuum(_ id: String) async { calls.append(.stop(id)) }
    func returnVacuumToBase(_ id: String) async { calls.append(.returnToBase(id)) }
    func locateVacuum(_ id: String) async { calls.append(.locate(id)) }
}
