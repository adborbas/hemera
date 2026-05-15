import Foundation
import SwiftData

@Model
final class AreaEntity {
    @Attribute(.unique)
    var areaId: String
    var name: String
    var icon: String?
    var sortOrder: Int

    // Inverse relationships (optional but handy)
    @Relationship(inverse: \LightEntity.area)
    var lights: [LightEntity] = []

    @Relationship(inverse: \CoverEntity.area)
    var covers: [CoverEntity] = []

    @Relationship(inverse: \SceneEntity.area)
    var scenes: [SceneEntity] = []

    @Relationship(inverse: \SensorEntity.area)
    var sensors: [SensorEntity] = []

    @Relationship(inverse: \BinarySensorEntity.area)
    var binarySensors: [BinarySensorEntity] = []

    @Relationship(inverse: \SwitchEntity.area)
    var switches: [SwitchEntity] = []

    @Relationship(inverse: \ButtonEntity.area)
    var buttons: [ButtonEntity] = []

    @Relationship(inverse: \AutomationEntity.area)
    var automations: [AutomationEntity] = []

    @Relationship(inverse: \ClimateEntity.area)
    var climates: [ClimateEntity] = []

    init(areaId: String, name: String, icon: String? = nil, sortOrder: Int = 0) {
        self.areaId = areaId
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
    }

    @discardableResult
    static func upsert(id: String, name: String, icon: String?, sortOrder: Int, in context: ModelContext) -> AreaEntity {
        let descriptor = FetchDescriptor<AreaEntity>(
            predicate: #Predicate { $0.areaId == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.name = name
            existing.icon = icon
            existing.sortOrder = sortOrder
            return existing
        }
        let area = AreaEntity(areaId: id, name: name, icon: icon, sortOrder: sortOrder)
        context.insert(area)
        return area
    }
}
