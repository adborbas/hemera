import Foundation

/// An area and the entities Home Assistant places in it.
struct AreaMapping: Sendable {
    let areaId: String
    let areaName: String
    let entities: [String]
}

/**
 Resolves area membership from the registries, mirroring Home Assistant's `area_entities()`:
 an entity's own area wins, otherwise it inherits the area of its device.
*/
enum AreaMappingResolver {

    static func resolve(
        areas: [AreaRegistryEntry],
        entityAreaIds: [String: String],
        deviceMappings: [DeviceMapping],
        devices: [DeviceRegistryEntry]
    ) -> [AreaMapping] {
        let knownAreaIds = Set(areas.map(\.areaId))
        let deviceAreaIds = Dictionary(
            devices.compactMap { device in device.areaId.map { (device.deviceId, $0) } },
            uniquingKeysWith: { _, new in new }
        )

        var entityIdsByArea: [String: [String]] = [:]
        for mapping in deviceMappings {
            guard entityAreaIds[mapping.entityId] == nil,
                  let areaId = deviceAreaIds[mapping.deviceId],
                  knownAreaIds.contains(areaId)
            else { continue }
            entityIdsByArea[areaId, default: []].append(mapping.entityId)
        }
        for (entityId, areaId) in entityAreaIds where knownAreaIds.contains(areaId) {
            entityIdsByArea[areaId, default: []].append(entityId)
        }

        return areas.map { area in
            AreaMapping(
                areaId: area.areaId,
                areaName: area.name,
                entities: (entityIdsByArea[area.areaId] ?? []).sorted()
            )
        }
    }
}
