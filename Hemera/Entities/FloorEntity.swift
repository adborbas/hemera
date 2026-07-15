import Foundation
import SwiftData

/// A Home Assistant floor. Registry metadata (like `AreaEntity`), not an HA
/// state entity — so it does not conform to `StoredEntity`.
@Model
final class FloorEntity {
    @Attribute(.unique)
    var floorId: String
    var name: String
    var level: Int?
    var sortOrder: Int

    @Relationship(inverse: \AreaEntity.floor)
    var areas: [AreaEntity] = []

    init(floorId: String, name: String, level: Int? = nil, sortOrder: Int = 0) {
        self.floorId = floorId
        self.name = name
        self.level = level
        self.sortOrder = sortOrder
    }

    @discardableResult
    static func upsert(id: String, name: String, level: Int?, sortOrder: Int, in context: ModelContext) -> FloorEntity {
        let descriptor = FetchDescriptor<FloorEntity>(
            predicate: #Predicate { $0.floorId == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.name = name
            existing.level = level
            existing.sortOrder = sortOrder
            return existing
        }
        let floor = FloorEntity(floorId: id, name: name, level: level, sortOrder: sortOrder)
        context.insert(floor)
        return floor
    }
}
