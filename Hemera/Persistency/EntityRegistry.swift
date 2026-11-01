import SwiftData
import Synchronization
import HAKit
import HemeraLog
import Foundation

/// Central registry for entity types, enabling scalable entity type support.
///
/// Entity types are registered once at app startup in `AppEnvironment.registerEntities()`.
/// The registry dispatches upserts and area assignments to the correct entity type by domain.
///
/// Thread-safe: `registrations` is protected by a `Mutex`. Registration happens once at
/// startup, then only read operations occur during sync.
final class EntityRegistry: Sendable {

    struct Registration: Sendable {
        let domain: String
        let entityType: any StoredEntity.Type
        let upsert: @Sendable (ModelContext, HAEntity) -> Void
        let assignArea: @Sendable (AreaEntity, String, ModelContext) -> Bool
        let assignDeviceId: @Sendable (String, String, ModelContext) -> Bool
        let markMissing: @Sendable (Set<String>, ModelContext) -> Void
        let clearAreas: @Sendable (Set<String>, ModelContext) -> Void
        let applyHAHidden: @Sendable (Set<String>, ModelContext) -> Void
    }

    static let shared = EntityRegistry()

    private let registrations = Mutex<[String: Registration]>([:])

    private init() {
        // Empty - registrations are triggered externally to avoid circular dependency
    }

    /// Registers an entity type with its persistence closures.
    /// Called once from `AppEnvironment.registerEntities()` at app startup.
    func register<T: StoredEntity>(_ type: T.Type) {
        let domain = type.domain
        registrations.withLock { dict in
            dict[domain] = Registration(
                domain: domain,
                entityType: type,
                upsert: { context, entity in
                    type.performUpsert(in: context, from: entity)
                },
                assignArea: { area, entityId, context in
                    type.assignAreaIfMatch(area, entityId: entityId, in: context)
                },
                assignDeviceId: { deviceId, entityId, context in
                    type.assignDeviceIdIfMatch(deviceId, entityId: entityId, in: context)
                },
                markMissing: { serverEntityIds, context in
                    type.markMissingAsUnavailable(serverEntityIds: serverEntityIds, in: context)
                },
                clearAreas: { keptEntityIds, context in
                    type.clearAreaIfNotIn(keptEntityIds, in: context)
                },
                applyHAHidden: { hiddenEntityIds, context in
                    type.applyHAHidden(hiddenEntityIds: hiddenEntityIds, in: context)
                }

            )
        }
    }

    // MARK: - Delegation Methods

    /// Upserts an entity from Home Assistant into storage.
    /// Delegates to the registered entity type's implementation.
    func upsert(from entity: HAEntity, in context: ModelContext) {
        guard let registration = registrations.withLock({ $0[entity.domain] }) else { return }
        registration.upsert(context, entity)
    }

    /// Assigns an area to an entity by ID.
    func assignArea(_ area: AreaEntity, toEntityWithId entityId: String, in context: ModelContext) {
        guard let registration = registration(forEntityId: entityId) else { return }
        _ = registration.assignArea(area, entityId, context)
    }

    /// Assigns a device ID to an entity by its entity ID.
    func assignDeviceId(_ deviceId: String, toEntityWithId entityId: String, in context: ModelContext) {
        guard let registration = registration(forEntityId: entityId) else { return }
        _ = registration.assignDeviceId(deviceId, entityId, context)
    }

    /// HA ids are `"<domain>.<object>"`, so one lookup replaces a fetch per registered type.
    private func registration(forEntityId entityId: String) -> Registration? {
        let domain = String(entityId.prefix { $0 != "." })
        return registrations.withLock { $0[domain] }
    }

    /// Marks entities as unavailable if they were not present in the last full sync.
    /// Dispatches to each registered entity type.
    func markMissingEntitiesAsUnavailable(serverEntityIds: Set<String>, in context: ModelContext) {
        let regs = registrations.withLock { Array($0.values) }
        for registration in regs {
            registration.markMissing(serverEntityIds, context)
        }
    }

    /**
     Clears the area link on entities whose id is not in the given set.
     Dispatches to each registered entity type. Called during a full sync so
     entities the server no longer places in any area move back to Unassigned.
     */
    func clearAreasForEntities(notIn keptEntityIds: Set<String>, in context: ModelContext) {
        let regs = registrations.withLock { Array($0.values) }
        for registration in regs {
            registration.clearAreas(keptEntityIds, context)
        }
    }

    /**
     Sets `isHiddenInHA` on all entities from Home Assistant's registry hidden set
     (`hidden_by != nil`). Dispatches to each registered entity type. Called during
     a full sync, only when the entity-registry fetch succeeded.
    */
    func applyHAHidden(_ hiddenEntityIds: Set<String>, in context: ModelContext) {
        let regs = registrations.withLock { Array($0.values) }
        for registration in regs {
            registration.applyHAHidden(hiddenEntityIds, context)
        }
    }

    /// All registered entity types, for building the SwiftData Schema.
    var allEntityTypes: [any PersistentModel.Type] {
        registrations.withLock { $0.values.map { $0.entityType as any PersistentModel.Type } }
    }
}
