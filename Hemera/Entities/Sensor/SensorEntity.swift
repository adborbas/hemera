import SwiftData
import HAKit
import Foundation

@Model
final class SensorEntity: StoredEntity {

    static let domain = "sensor"

    @Attribute(.unique) var entityId: String
    var name: String
    var state: String
    var deviceClass: String?
    var stateClass: String?
    var unitOfMeasurement: String?
    var icon: String?
    var deviceId: String?
    var entityName: String?
    var isAvailable: Bool = true
    var isHidden: Bool = false
    var isHiddenInHA: Bool = false
    var area: AreaEntity?

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "", state: "")
    }

    init(entityId: String, name: String, state: String, deviceClass: String? = nil, unitOfMeasurement: String? = nil, icon: String? = nil, stateClass: String? = nil) {
        self.entityId = entityId
        self.name = name
        self.state = state
        self.deviceClass = deviceClass
        self.unitOfMeasurement = unitOfMeasurement
        self.icon = icon
        self.stateClass = stateClass
    }

    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId
        state = entity.state
        deviceClass = entity.attributes["device_class"] as? String
        stateClass = entity.attributes["state_class"] as? String
        unitOfMeasurement = entity.attributes["unit_of_measurement"] as? String
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - StoredEntity

extension SensorEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<SensorEntity> {
        #Predicate { $0.entityId == id }
    }
}

// MARK: - RegistryNamed

/// Named on the device Sensors page without the device's name; `nil` until a full sync sets it.
extension SensorEntity: RegistryNamed {}
