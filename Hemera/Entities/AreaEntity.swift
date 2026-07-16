import Foundation
import SwiftData

@Model
final class AreaEntity {
    @Attribute(.unique)
    var areaId: String
    var name: String
    var icon: String?
    var sortOrder: Int

    /// The floor this area belongs to, when Home Assistant assigns one.
    /// Optional — additive, lightweight-migration-safe.
    var floor: FloorEntity?

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

    /**
     Deletes stored areas whose id is not in the given set.
     Called after upserting during a full sync — only when the area-mapping fetch
     succeeded — so an area deleted server-side is removed locally. SwiftData nullifies
     the inverse entity relationships on delete, so entities in a deleted area move to
     Unassigned rather than dangling. Mirrors `HADataSyncService.pruneFloors`.
     */
    static func prune(keeping serverAreaIds: Set<String>, in context: ModelContext) {
        guard let stored = try? context.fetch(FetchDescriptor<AreaEntity>()) else { return }
        for area in stored where !serverAreaIds.contains(area.areaId) {
            context.delete(area)
        }
    }
}
