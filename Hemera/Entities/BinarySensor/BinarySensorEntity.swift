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
    /**
     Home Assistant's raw `device_class` string.

     `DeviceClass` models only the handful of classes Hemera branches on for colour and wording,
     but HA ships ~30. Icon resolution needs the unmodelled ones too, otherwise every moisture,
     battery or tamper sensor falls back to the generic domain icon.
    */
    var deviceClassRaw: String?
    var icon: String?
    var deviceId: String?
    var isAvailable: Bool = true
    var isHidden: Bool = false
    var isHiddenInHA: Bool = false
    var area: AreaEntity?

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "", state: .unknown)
    }

    init(
        entityId: String,
        name: String,
        state: State,
        deviceClass: DeviceClass = .unknown,
        deviceClassRaw: String? = nil,
        icon: String? = nil
    ) {
        self.entityId = entityId
        self.name = name
        self.state = state
        self.deviceClass = deviceClass
        self.deviceClassRaw = deviceClassRaw ?? (deviceClass == .unknown ? nil : deviceClass.rawValue)
        self.icon = icon
    }

    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId
        state = State(rawValue: entity.state) ?? .unknown

        let rawDeviceClass = entity.attributes["device_class"] as? String
        deviceClassRaw = rawDeviceClass
        deviceClass = DeviceClass(rawValue: rawDeviceClass ?? "") ?? .unknown
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
