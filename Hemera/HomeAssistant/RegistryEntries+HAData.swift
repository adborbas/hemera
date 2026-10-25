import Foundation
import HAKit

// `nil` for a non-list response: a shape we can't read is a failed fetch, not an empty registry.

extension AreaRegistryEntry {

    init?(haData: HAData) {
        guard case let .dictionary(dict) = haData,
              let areaId = dict["area_id"] as? String
        else { return nil }

        self.init(
            areaId: areaId,
            floorId: dict["floor_id"] as? String,
            icon: dict["icon"] as? String
        )
    }

    /// Decodes `config/area_registry/list`, preserving registry order.
    static func decodeList(_ haData: HAData) -> [AreaRegistryEntry]? {
        guard case let .array(entries) = haData else { return nil }
        return entries.compactMap(AreaRegistryEntry.init(haData:))
    }
}

extension FloorRegistryEntry {

    init?(haData: HAData) {
        guard case let .dictionary(dict) = haData,
              let floorId = dict["floor_id"] as? String,
              let name = dict["name"] as? String
        else { return nil }

        self.init(floorId: floorId, name: name, level: dict["level"] as? Int)
    }

    static func decodeList(_ haData: HAData) -> [FloorRegistryEntry]? {
        guard case let .array(entries) = haData else { return nil }
        return entries.compactMap(FloorRegistryEntry.init(haData:))
    }
}

/// Maps an entity to its parent device from the HA entity registry.
struct DeviceMapping: Sendable {
    let entityId: String
    let deviceId: String
}

/// The slice of the entity registry Hemera reads: device links, and HA-hidden entities.
struct EntityRegistrySnapshot: Sendable {
    let deviceMappings: [DeviceMapping]
    let hiddenEntityIds: Set<String>

    static func decode(_ haData: HAData) -> EntityRegistrySnapshot? {
        guard case let .array(entries) = haData else { return nil }

        var deviceMappings: [DeviceMapping] = []
        var hiddenEntityIds: Set<String> = []
        for entry in entries {
            guard case let .dictionary(dict) = entry,
                  let entityId = dict["entity_id"] as? String
            else { continue }
            if let deviceId = dict["device_id"] as? String {
                deviceMappings.append(DeviceMapping(entityId: entityId, deviceId: deviceId))
            }
            // `hidden_by` is a non-null string ("user"/"integration") when hidden.
            if dict["hidden_by"] as? String != nil {
                hiddenEntityIds.insert(entityId)
            }
        }
        return EntityRegistrySnapshot(deviceMappings: deviceMappings, hiddenEntityIds: hiddenEntityIds)
    }
}
