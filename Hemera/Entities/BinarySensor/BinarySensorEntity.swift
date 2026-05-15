import SwiftData
import HAKit
import Foundation

@Model
final class BinarySensorEntity: StoredEntity {

    static let domain = "binary_sensor"

    @Attribute(.unique) var entityId: String
    var name: String
    var state: State
    var deviceClass: DeviceClass
    var icon: String?
    var deviceId: String?
    var isAvailable: Bool = true
    var area: AreaEntity?

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "", state: .unknown)
    }

    init(
        entityId: String,
        name: String,
        state: State,
        deviceClass: DeviceClass = .unknown,
        icon: String? = nil
    ) {
        self.entityId = entityId
        self.name = name
        self.state = state
        self.deviceClass = deviceClass
        self.icon = icon
    }

    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId
        state = State(rawValue: entity.state) ?? .unknown

        let deviceClassRaw = entity.attributes["device_class"] as? String
        deviceClass = DeviceClass(rawValue: deviceClassRaw ?? "") ?? .unknown
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - StoredEntity

extension BinarySensorEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<BinarySensorEntity> {
        #Predicate { $0.entityId == id }
    }

    static var unassignedPredicate: Predicate<BinarySensorEntity> {
        #Predicate { $0.area == nil && $0.isAvailable == true }
    }
}

// MARK: - Types

extension BinarySensorEntity {
    enum State: String, Codable, CaseIterable, Identifiable {
        case on, off, unknown, unavailable

        var id: String { rawValue }
    }

    enum DeviceClass: String, Codable, CaseIterable, Identifiable {
        case motion
        case door
        case window
        case smoke
        case occupancy
        case unknown

        var id: String { rawValue }
    }
}

// MARK: - Device Class Symbols

extension BinarySensorEntity.DeviceClass {

    func symbolName(isOn: Bool) -> String {
        switch self {
        case .motion:
            return isOn ? "figure.walk" : "figure.stand"
        case .door:
            return isOn ? "door.left.hand.open" : "door.left.hand.closed"
        case .window:
            return isOn ? "window.vertical.open" : "window.vertical.closed"
        case .smoke:
            return isOn ? "smoke.fill" : "smoke"
        case .occupancy:
            return isOn ? "person.fill" : "person"
        case .unknown:
            return isOn ? "circle.fill" : "circle"
        }
    }
}
