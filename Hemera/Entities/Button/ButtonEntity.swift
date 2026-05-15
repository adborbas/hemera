import SwiftData
import HAKit
import Foundation

@Model
final class ButtonEntity: StoredEntity {

    static let domain = "button"

    @Attribute(.unique) var entityId: String
    var name: String
    var deviceClass: DeviceClass
    var icon: String?
    var deviceId: String?
    var isAvailable: Bool = true
    var area: AreaEntity?

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "")
    }

    init(entityId: String, name: String, deviceClass: DeviceClass = .unknown, icon: String? = nil) {
        self.entityId = entityId
        self.name = name
        self.deviceClass = deviceClass
        self.icon = icon
    }

    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId

        let deviceClassRaw = entity.attributes["device_class"] as? String
        deviceClass = DeviceClass(rawValue: deviceClassRaw ?? "") ?? .unknown
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - StoredEntity

extension ButtonEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<ButtonEntity> {
        #Predicate { $0.entityId == id }
    }

    static var unassignedPredicate: Predicate<ButtonEntity> {
        #Predicate { $0.area == nil && $0.isAvailable == true }
    }
}

// MARK: - Types

extension ButtonEntity {
    enum DeviceClass: String, Codable, CaseIterable, Identifiable {
        case restart
        case update
        case identify
        case unknown

        var id: String { rawValue }

        var isUserActionable: Bool {
            switch self {
            case .restart, .update: true
            case .identify, .unknown: false
            }
        }

        var requiresConfirmation: Bool {
            switch self {
            case .restart, .update: true
            case .identify, .unknown: false
            }
        }
    }
}
