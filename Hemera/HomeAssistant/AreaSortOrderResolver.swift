import Foundation

/// An area entry from the Home Assistant area registry WebSocket API.
struct AreaRegistryEntry: Sendable {
    let areaId: String
    let floorId: String?
    let icon: String?

    init(areaId: String, floorId: String?, icon: String? = nil) {
        self.areaId = areaId
        self.floorId = floorId
        self.icon = icon
    }
}

/// A floor entry from the Home Assistant floor registry WebSocket API.
struct FloorRegistryEntry: Sendable {
    let floorId: String
    let name: String
    let level: Int?
}

/// Computes area display positions matching Home Assistant's dashboard order.
///
/// The ordering mirrors how the HA frontend renders areas:
/// 1. Floors in registry order (the sequence returned by `config/floor_registry/list`,
///    which reflects the user's custom drag-and-drop arrangement).
/// 2. Areas within each floor in their registry order (from `config/area_registry/list`).
/// 3. Areas not assigned to any floor come after all floored areas, in registry order.
///
/// Returns an empty dictionary when given empty input, allowing callers to fall back
/// to their own ordering (e.g. enumerated index).
enum AreaSortOrderResolver {

    static func resolve(
        areas: [AreaRegistryEntry],
        floors: [FloorRegistryEntry]
    ) -> [String: Int] {
        guard !areas.isEmpty else { return [:] }

        let floorIds = Set(floors.map(\.floorId))
        var orderedAreaIds: [String] = []

        for floor in floors {
            for area in areas where area.floorId == floor.floorId {
                orderedAreaIds.append(area.areaId)
            }
        }

        for area in areas {
            guard let floorId = area.floorId, floorIds.contains(floorId) else {
                orderedAreaIds.append(area.areaId)
                continue
            }
        }

        var result: [String: Int] = [:]
        for (index, areaId) in orderedAreaIds.enumerated() {
            result[areaId] = index
        }
        return result
    }
}
