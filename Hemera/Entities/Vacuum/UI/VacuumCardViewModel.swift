import Foundation
import Mortar
import SwiftData
import SwiftUI

@Observable
@MainActor
final class VacuumCardViewModel: Identifiable {
    enum Action {
        case start, pause, stop, returnToBase, locate
    }

    enum RobotMotion {
        case wander, headingHome, errorPulse
    }

    /// A round button in the control panel; disabled ones stay visible so the row doesn't reflow.
    struct PanelButton: Equatable, Identifiable {
        let action: Action
        let isEnabled: Bool

        var id: Action { action }
    }

    private(set) var vacuum: VacuumEntity

    nonisolated let id: String
    var name: String { vacuum.name }
    var isAvailable: Bool { vacuum.isAvailable }
    var deviceId: String? { vacuum.deviceId }
    var isHidden: Bool {
        get { vacuum.isHidden }
        set { vacuum.isHidden = newValue }
    }
    var state: VacuumEntity.State { vacuum.state }

    private let controller: VacuumControlling
    private let iconResolver: any IconResolving
    private(set) var actionTask: Task<Void, Never>?

    var stateDescription: String {
        switch state {
        case .cleaning:    Localization.cleaning
        case .docked:      Localization.docked
        case .idle:        Localization.idle
        case .paused:      Localization.paused
        case .returning:   Localization.returning
        case .error:       Localization.error
        case .unknown:     Localization.unknown
        case .unavailable: Localization.unavailable
        }
    }

    var isWorking: Bool { state == .cleaning || state == .returning }

    var isActive: Bool { isWorking || state == .error }

    var tintColor: Color { state == .error ? .red : .teal }

    var iconBackgroundColor: Color { isActive ? tintColor : PlatformColor.systemGray3 }

    var iconName: String? {
        iconResolver.iconName(domain: VacuumEntity.domain, state: state.rawValue, entityIcon: vacuum.icon)
    }

    // Returning, error and unknown states do nothing, so a stray tap never sends the robot anywhere.
    var iconAction: Action? {
        guard vacuum.isAvailable else { return nil }
        let features = vacuum.supportedFeatures
        switch state {
        case .docked, .idle, .paused:
            return features.contains(.start) ? .start : nil
        case .cleaning:
            if features.contains(.pause) { return .pause }
            return features.contains(.stop) ? .stop : nil
        case .returning, .error, .unknown, .unavailable:
            return nil
        }
    }

    /// What VoiceOver calls `iconTapped`. Nil hides the icon, as tapping it does nothing.
    var iconActionLabel: String? { iconAction?.label }

    /// Primary first: Pause while moving, else Stop if the robot can't pause, else Start.
    var panelButtons: [PanelButton] {
        let features = vacuum.supportedFeatures
        let primary: Action = if isWorking && features.contains(.pause) {
            .pause
        } else if isWorking && features.contains(.stop) {
            .stop
        } else {
            .start
        }
        return ([primary] + [Action.stop, .returnToBase, .locate].filter { $0 != primary })
            .filter { features.contains($0.feature) }
            .map { PanelButton(action: $0, isEnabled: isEnabled($0)) }
    }

    /// How the panel's robot moves; `nil` keeps it still, as Reduce Motion always does.
    func robotMotion(reduceMotion: Bool) -> RobotMotion? {
        guard !reduceMotion else { return nil }
        return switch state {
        case .cleaning: .wander
        case .returning: .headingHome
        case .error: .errorPulse
        case .docked, .idle, .paused, .unknown, .unavailable: nil
        }
    }

    // MARK: - Battery

    /// Battery % from the sensor on the robot's device; `nil` hides the battery line.
    var batteryLevel: Double? {
        guard let deviceId = vacuum.deviceId, let context = vacuum.modelContext else { return nil }
        let device: String? = deviceId
        let battery: String? = Self.batteryDeviceClass
        var descriptor = FetchDescriptor<SensorEntity>(
            predicate: #Predicate { $0.deviceId == device && $0.deviceClass == battery && $0.isAvailable },
            sortBy: [SortDescriptor(\.entityId)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first.flatMap { Double($0.state) }
    }

    var isCharging: Bool {
        guard let deviceId = vacuum.deviceId, let context = vacuum.modelContext else { return false }
        let device: String? = deviceId
        let charging: String? = BinarySensorEntity.DeviceClass.batteryCharging.rawValue
        let descriptor = FetchDescriptor<BinarySensorEntity>(
            predicate: #Predicate { $0.deviceId == device && $0.deviceClassRaw == charging && $0.isAvailable }
        )
        return (try? context.fetch(descriptor))?.contains { $0.state == .on } ?? false
    }

    var batteryIconName: String? {
        batteryLevel.map { Self.batteryIcon(level: $0, isCharging: isCharging) }
    }

    var batteryDescription: String? {
        batteryLevel.map { ($0 / 100).formatted(.percent.precision(.fractionLength(0))) }
    }

    /// Home Assistant frontend's `batteryLevelIcon`, so the glyph matches what HA shows.
    static func batteryIcon(level: Double, isCharging: Bool) -> String {
        let rounded = Int((level / 10).rounded()) * 10
        if isCharging && level >= 10 {
            return rounded >= 100 ? "mdi:battery-charging" : "mdi:battery-charging-\(rounded)"
        }
        if isCharging { return "mdi:battery-charging-outline" }
        if level <= 5 { return "mdi:battery-alert-variant-outline" }
        return rounded >= 100 ? "mdi:battery" : "mdi:battery-\(rounded)"
    }

    init(vacuum: VacuumEntity, controller: VacuumControlling, iconResolver: any IconResolving = IconResolver.shared) {
        self.id = vacuum.entityId
        self.vacuum = vacuum
        self.controller = controller
        self.iconResolver = iconResolver
    }

    // MARK: - Actions

    func iconTapped() {
        guard let action = iconAction else { return }
        perform(action)
    }

    func perform(_ action: Action) {
        actionTask?.cancel()
        actionTask = Task {
            switch action {
            case .start: await controller.startVacuum(id)
            case .pause: await controller.pauseVacuum(id)
            case .stop: await controller.stopVacuum(id)
            case .returnToBase: await controller.returnVacuumToBase(id)
            case .locate: await controller.locateVacuum(id)
            }
        }
    }
}

private extension VacuumCardViewModel {
    static let batteryDeviceClass = "battery"

    func isEnabled(_ action: Action) -> Bool {
        guard vacuum.isAvailable else { return false }
        return switch action {
        case .start: [.docked, .idle, .paused].contains(state)
        case .pause: isWorking
        case .stop: [.paused, .cleaning, .returning].contains(state)
        case .returnToBase: [.idle, .paused, .cleaning].contains(state)
        case .locate: ![.unknown, .unavailable].contains(state)
        }
    }
}

extension VacuumCardViewModel.Action {
    var feature: VacuumEntity.Features {
        switch self {
        case .start: .start
        case .pause: .pause
        case .stop: .stop
        case .returnToBase: .returnHome
        case .locate: .locate
        }
    }

    /// Home Assistant's own icons for these services.
    var iconName: String {
        switch self {
        case .start: "mdi:play"
        case .pause: "mdi:pause"
        case .stop: "mdi:stop"
        case .returnToBase: "mdi:home-import-outline"
        case .locate: "mdi:map-marker"
        }
    }

    var label: String {
        switch self {
        case .start: VacuumCardViewModel.Localization.startAction
        case .pause: VacuumCardViewModel.Localization.pauseAction
        case .stop: VacuumCardViewModel.Localization.stopAction
        case .returnToBase: VacuumCardViewModel.Localization.returnToBaseAction
        case .locate: VacuumCardViewModel.Localization.locateAction
        }
    }
}

private extension VacuumCardViewModel {
    enum Localization {
        static let cleaning = String(localized: "Cleaning", comment: "Robot vacuum state shown on card while it is cleaning")
        static let docked = String(localized: "Docked", comment: "Robot vacuum state shown on card when it sits in its charging dock")
        static let idle = String(localized: "Idle", comment: "Robot vacuum state shown on card when it is stopped away from its dock")
        static let paused = String(localized: "Paused", comment: "Robot vacuum state shown on card when cleaning is paused")
        static let returning = String(localized: "Returning", comment: "Robot vacuum state shown on card while it drives back to its dock")
        static let error = String(localized: "Error", comment: "Robot vacuum state shown on card when the robot reports an error, e.g. stuck")
        static let unknown = String(localized: "Unknown", comment: "Robot vacuum state shown on card when the state cannot be determined")
        static let unavailable = String(localized: "Unavailable", comment: "Robot vacuum state shown on card when the device is unreachable")
        static let startAction = String(localized: "Start", comment: "VoiceOver name for the card icon or panel button that starts the robot vacuum cleaning")
        static let pauseAction = String(localized: "Pause", comment: "VoiceOver name for the card icon or panel button that pauses the cleaning robot vacuum")
        static let stopAction = String(localized: "Stop", comment: "VoiceOver name for the card icon or panel button that stops the robot vacuum")
        static let returnToBaseAction = String(localized: "Return to dock", comment: "VoiceOver name for the panel button that sends the robot vacuum back to its charging dock")
        static let locateAction = String(localized: "Locate", comment: "VoiceOver name for the panel button that makes the robot vacuum beep so it can be found")
    }
}

// MARK: - Factory Registration

extension VacuumCardViewModel {
    static func registration(controller: VacuumControlling) -> ViewModelFactory.Registration {
        ViewModelFactory.Registration(
            domain: VacuumEntity.domain,
            makeViewModelsForArea: { area in
                area.vacuums.filter { !$0.isHiddenInHA }.sorted(by: { $0.entityId < $1.entityId }).map {
                    VacuumCardViewModel(vacuum: $0, controller: controller)
                }
            },
            makeViewModelForEntityId: { entityId, context in
                guard let vacuum = VacuumEntity.fetch(byId: entityId, in: context) else { return nil }
                return VacuumCardViewModel(vacuum: vacuum, controller: controller)
            },
            entityExists: { entityId, context in
                VacuumEntity.fetch(byId: entityId, in: context) != nil
            }
        )
    }
}

// MARK: - EntityCardViewModel

extension VacuumCardViewModel: EntityCardViewModel {
    func makeCardView() -> AnyView {
        AnyView(VacuumCard(viewModel: self))
    }

    var hasOverlay: Bool { true }

    func makeOverlayView(isPresented: Binding<Bool>) -> AnyView? {
        AnyView(VacuumControlPanel(viewModel: self, isPresented: isPresented))
    }
}
