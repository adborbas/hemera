import SwiftData
import HAKit
import Foundation

@Model
final class SwitchEntity: StoredEntity {

    static let domain = "switch"

    @Attribute(.unique) var entityId: String
    var name: String
    var state: State
    var deviceClass: DeviceClass
    var icon: String?
    var deviceId: String?
    var isAvailable: Bool = true
    var area: AreaEntity?

    var isOn: Bool { state == .on }

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "", state: .unknown)
    }

    init(
        entityId: String,
        name: String,
        state: State,
        deviceClass: DeviceClass = .switch,
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
        deviceClass = DeviceClass(rawValue: deviceClassRaw ?? "") ?? .switch
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - StoredEntity

extension SwitchEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<SwitchEntity> {
        #Predicate { $0.entityId == id }
    }

    static var unassignedPredicate: Predicate<SwitchEntity> {
        #Predicate { $0.area == nil && $0.isAvailable == true }
    }
}

// MARK: - Types

extension SwitchEntity {
    enum State: String, Codable, CaseIterable, Identifiable {
        case on
        case off
        case unknown
        case unavailable

        var id: String { rawValue }
    }

    enum DeviceClass: String, Codable, CaseIterable, Identifiable {
        case outlet
        case `switch`

        var id: String { rawValue }
    }
}
