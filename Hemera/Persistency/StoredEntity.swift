import HAKit
import HemeraLog
import SwiftData
import Foundation

/// Protocol for entities that can be persisted and updated from Home Assistant.
///
/// Conforming types must provide:
/// - A static `domain` identifying the HA domain (e.g., "light", "cover")
/// - A settable `entityId` for storage lookup
/// - An `area` relationship for area assignment
/// - An `update(from:)` method to sync with HA state
/// - An `isAvailable` flag (app-computed, not HA state — see below)
/// - An `entityIdPredicate` for type-safe entity lookup
///
/// Default implementations of `performUpsert`, `assignAreaIfMatch`, and
/// `assignDeviceIdIfMatch` are provided via protocol extension — conforming
/// types do not need to implement these.
protocol StoredEntity: PersistentModel {
    static var domain: String { get }
    var entityId: String { get set }
    var deviceId: String? { get set }
    var area: AreaEntity? { get set }

    /// Whether this entity still exists on the Home Assistant server.
    ///
    /// This is app-computed metadata, distinct from HA's native `"unavailable"` state
    /// (which means the device is temporarily unreachable). `isAvailable == false` means
    /// the entity was not present in the last full sync from the server.
    var isAvailable: Bool { get set }

    /// Returns a predicate matching a single entity by its entityId.
    ///
    /// Each concrete `@Model` type must implement this so that `#Predicate` expands
    /// at the concrete type level. `#Predicate` must never reference `StoredEntity`
    /// properties through any generic or protocol-extension context — only from
    /// concrete `@Model` type scope — to avoid SwiftData keypath identity mismatches
    /// in release builds.
    static func entityIdPredicate(_ id: String) -> Predicate<Self>

    /// Returns a predicate matching entities not assigned to any area.
    ///
    /// Same concrete-type requirement as `entityIdPredicate` — see above.
    static var unassignedPredicate: Predicate<Self> { get }

    init(entityId: String)
    func update(from entity: HAEntity)
}

// MARK: - Default Persistence Implementations
// Note: These are extension methods (not protocol requirements), so they use static dispatch.
// Entity types cannot override them. If a custom upsert is ever needed, promote to protocol requirements.

extension StoredEntity {

    /// Upserts an entity from Home Assistant into storage.
    /// Fetches by entityId using a predicate for O(1) lookup, then updates or inserts.
    static func performUpsert(in context: ModelContext, from entity: HAEntity) {
        let id = entity.entityId
        let descriptor = FetchDescriptor<Self>(
            predicate: entityIdPredicate(id)
        )

        let existing: Self?
        do {
            existing = try context.fetch(descriptor).first
        } catch {
            Log.warning("Failed to fetch \(Self.domain) entity \(id) for upsert", cause: error)
            existing = nil
        }

        if let existing {
            existing.update(from: entity)
            existing.isAvailable = true
        } else {
            let newEntity = Self(entityId: id)
            newEntity.update(from: entity)
            newEntity.isAvailable = true
            context.insert(newEntity)
        }
    }

    /// Fetches a single entity by its entityId, or nil if not found.
    static func fetch(byId entityId: String, in context: ModelContext) -> Self? {
        let descriptor = FetchDescriptor<Self>(
            predicate: entityIdPredicate(entityId)
        )
        do {
            return try context.fetch(descriptor).first
        } catch {
            Log.warning("Failed to fetch \(Self.domain) entity \(entityId)", cause: error)
            return nil
        }
    }

    /// Attempts to assign an area to an entity with the given ID.
    /// Returns true if the entity was found and assigned.
    static func assignAreaIfMatch(_ area: AreaEntity, entityId: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Self>(
            predicate: entityIdPredicate(entityId)
        )
        do {
            if let entity = try context.fetch(descriptor).first {
                entity.area = area
                return true
            }
        } catch {
            Log.warning("Failed to fetch \(Self.domain) entity \(entityId) for area assignment", cause: error)
        }
        return false
    }

    /// Attempts to assign a device ID to an entity with the given entity ID.
    /// Returns true if the entity was found and assigned.
    static func assignDeviceIdIfMatch(_ deviceId: String, entityId: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Self>(
            predicate: entityIdPredicate(entityId)
        )
        do {
            if let entity = try context.fetch(descriptor).first {
                entity.deviceId = deviceId
                return true
            }
        } catch {
            Log.warning("Failed to fetch \(Self.domain) entity \(entityId) for device ID assignment", cause: error)
        }
        return false
    }

    /// Marks all entities of this type as unavailable if their entityId is not in the given set.
    /// Called after a full sync to flag entities that no longer exist on the server.
    static func markMissingAsUnavailable(serverEntityIds: Set<String>, in context: ModelContext) {
        let descriptor = FetchDescriptor<Self>()
        let allEntities: [Self]
        do {
            allEntities = try context.fetch(descriptor)
        } catch {
            Log.warning("Failed to fetch \(Self.domain) entities for availability check", cause: error)
            return
        }
        for entity in allEntities where !serverEntityIds.contains(entity.entityId) {
            entity.isAvailable = false
        }
    }

    /// Clears the area link on all entities of this type whose entityId is not in the given set.
    /// Called during a full sync — only when the area-mapping fetch succeeded — so an entity
    /// removed from all areas server-side moves back to Unassigned instead of sticking to its
    /// old area. Fetches all of `Self` and filters in Swift (no `#Predicate` in generic scope,
    /// matching `markMissingAsUnavailable`).
    static func clearAreaIfNotIn(_ keptEntityIds: Set<String>, in context: ModelContext) {
        let descriptor = FetchDescriptor<Self>()
        let allEntities: [Self]
        do {
            allEntities = try context.fetch(descriptor)
        } catch {
            Log.warning("Failed to fetch \(Self.domain) entities for area reconciliation", cause: error)
            return
        }
        for entity in allEntities where entity.area != nil && !keptEntityIds.contains(entity.entityId) {
            entity.area = nil
        }
    }
}
