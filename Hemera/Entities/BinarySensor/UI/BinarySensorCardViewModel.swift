import Foundation
import Mortar
import SwiftData
import SwiftUI

@Observable
@MainActor
final class BinarySensorCardViewModel: Identifiable {
    private(set) var binarySensor: BinarySensorEntity

    nonisolated let id: String
    var name: String { binarySensor.name }
    var isOn: Bool { binarySensor.state == .on }
    var isAvailable: Bool { binarySensor.isAvailable }
    var deviceId: String? { binarySensor.deviceId }

    init(binarySensor: BinarySensorEntity) {
        self.id = binarySensor.entityId
        self.binarySensor = binarySensor
    }

    var iconName: String {
        switch binarySensor.state {
        case .unknown:
            return "questionmark.circle"
        case .unavailable:
            return "exclamationmark.circle"
        case .on, .off:
            return binarySensor.deviceClass.symbolName(isOn: isOn)
        }
    }

    var tintColor: Color {
        binarySensor.deviceClass == .smoke ? .red : .teal
    }

    var iconBackgroundColor: Color {
        switch binarySensor.state {
        case .on:
            return tintColor
        case .off, .unknown, .unavailable:
            return PlatformColor.systemGray3
        }
    }

    var stateDescription: String {
        switch binarySensor.state {
        case .unknown:
            return Localization.unknown
        case .unavailable:
            return Localization.unavailable
        case .on:
            return binarySensor.deviceClass.onDescription
        case .off:
            return binarySensor.deviceClass.offDescription
        }
    }
}

// MARK: - Factory Registration

extension BinarySensorCardViewModel {
    static func registration() -> ViewModelFactory.Registration {
        ViewModelFactory.Registration(
            makeViewModelsForArea: { area in
                area.binarySensors.sorted(by: { $0.entityId < $1.entityId }).map {
                    BinarySensorCardViewModel(binarySensor: $0)
                }
            },
            makeViewModelForEntityId: { entityId, context in
                guard let binarySensor = BinarySensorEntity.fetch(byId: entityId, in: context) else { return nil }
                return BinarySensorCardViewModel(binarySensor: binarySensor)
            }
        )
    }
}

// MARK: - EntityCardViewModel

extension BinarySensorCardViewModel: EntityCardViewModel {
    func makeCardView() -> AnyView {
        AnyView(BinarySensorCard(viewModel: self))
    }
}

// MARK: - Device Class Helpers

private extension BinarySensorEntity.DeviceClass {

    var onDescription: String {
        switch self {
        case .motion:    Localization.detected
        case .door:      Localization.open
        case .window:    Localization.open
        case .smoke:     Localization.detected
        case .occupancy: Localization.occupied
        case .unknown:   Localization.on
        }
    }

    var offDescription: String {
        switch self {
        case .motion:    Localization.clear
        case .door:      Localization.closed
        case .window:    Localization.closed
        case .smoke:     Localization.clear
        case .occupancy: Localization.clear
        case .unknown:   Localization.off
        }
    }
}

// MARK: - Localization

private enum Localization {
    static let detected = String(localized: "Detected", comment: "Binary sensor state shown when motion/smoke is detected")
    static let clear = String(localized: "Clear", comment: "Binary sensor state shown when no motion/smoke/occupancy is detected")
    static let open = String(localized: "Open", comment: "Binary sensor state shown when a door or window is open")
    static let closed = String(localized: "Closed", comment: "Binary sensor state shown when a door or window is closed")
    static let occupied = String(localized: "Occupied", comment: "Binary sensor state shown when occupancy is detected")
    static let on = String(localized: "On", comment: "Binary sensor generic on state")
    static let off = String(localized: "Off", comment: "Binary sensor generic off state")
    static let unknown = String(localized: "Unknown", comment: "Binary sensor state shown when the state cannot be determined")
    static let unavailable = String(localized: "Unavailable", comment: "Binary sensor state shown when the device is unreachable")
}
