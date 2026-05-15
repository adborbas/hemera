import SwiftData
import HAKit
import Foundation

@Model
final class SceneEntity: StoredEntity {

    static let domain = "scene"

@Attribute(.unique) var entityId: String
    var name: String
    var icon: String?
    var deviceId: String?
    var isAvailable: Bool = true
    var area: AreaEntity?

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "")
    }

    init(entityId: String, name: String, icon: String? = nil) {
        self.entityId = entityId
        self.name = name
        self.icon = icon
    }

    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - StoredEntity

extension SceneEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<SceneEntity> {
        #Predicate { $0.entityId == id }
    }

    static var unassignedPredicate: Predicate<SceneEntity> {
        #Predicate { $0.area == nil && $0.isAvailable == true }
    }
}
