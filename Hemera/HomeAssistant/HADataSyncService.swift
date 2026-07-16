import Foundation
import HAKit
import HemeraLog
import SwiftData

/// Fetches initial entity states and subscribes to real-time changes.
///
/// Bulk sync writes through `mainContext` in batches, saving and yielding
/// between batches so the UI stays responsive and `@Query` consumers see
/// progressive fill on cold start. Writing on the main context (rather
/// than a background `@ModelActor`) is required because SwiftData's
/// cross-context auto-merge updates storage but does NOT fire `@Observable`
/// on `@Model` objects — so card views observing per-entity properties
/// would otherwise stay stale until the next save on `mainContext`.
///
/// Real-time `state_changed` events use the same path: in-place mutation
/// on `mainContext` fires `@Model` observation; the trailing save fires
/// `@Query` reactivity.
@MainActor
final class HADataSyncService {

    /// Number of entity upserts (or area / device-mapping writes) processed
    /// before yielding back to the run loop. Tuned to keep cold-start sync
    /// responsive on cache-large installs.
    private static let yieldBatchSize = 50

    private let connectionManager: HAConnectionManager
    private let restClient: HARESTClient
    private let mainContext: ModelContext
    private let entityRegistry: EntityRegistry
    private let errorNotifier: ErrorNotifier?
    private let onSyncComplete: @MainActor () -> Void

    private var stateChangedToken: HACancellable?

    deinit { stateChangedToken?.cancel() }

    private var conn: HAConnection { connectionManager.connection }

    init(
        connectionManager: HAConnectionManager,
        restClient: HARESTClient,
        mainContext: ModelContext,
        entityRegistry: EntityRegistry,
        errorNotifier: ErrorNotifier? = nil,
        onSyncComplete: @MainActor @escaping () -> Void
    ) {
        self.connectionManager = connectionManager
        self.restClient = restClient
        self.mainContext = mainContext
        self.entityRegistry = entityRegistry
        self.errorNotifier = errorNotifier
        self.onSyncComplete = onSyncComplete
    }

    func start() {
        Log.info("Starting initial data sync")
        Task {
            await syncAllData()
            subscribeToStateChanges()
        }
    }

    /// Re-fetches all data and re-subscribes to real-time changes (e.g. after reconnecting or pull-to-refresh).
    func resync() async {
        Log.info("Re-syncing all data")
        await syncAllData()
        subscribeToStateChanges()
    }

    // MARK: - Data Sync

    private func syncAllData() async {
        do {
            let payload = try await fetchSyncPayload()
            Log.info("Fetched \(payload.entities.count) entities, \(payload.areaMappings.count) areas, \(payload.floors?.count ?? 0) floors — applying to main context")

            await applySyncPayload(payload)

            errorNotifier?.clearSyncFailed()
            Log.info("Sync complete")
            onSyncComplete()
        } catch {
            Log.error("Failed to sync data", cause: error)
            errorNotifier?.showError(Localization.syncFailed)
            errorNotifier?.markSyncFailed()
            onSyncComplete()
        }
    }

    /// Writes a sync payload to `mainContext` in batches, saving and yielding
    /// between batches so `@Query` consumers pick up progressive fill on
    /// cold start and the UI stays responsive. Entity upserts that match an
    /// existing `@Model` mutate it in place, firing `@Observable` for any
    /// card view that already references it.
    private func applySyncPayload(_ payload: SyncPayload) async {
        for (index, entity) in payload.entities.enumerated() {
            entityRegistry.upsert(from: entity, in: mainContext)
            if (index + 1).isMultiple(of: Self.yieldBatchSize) {
                saveBatch("entity batch")
                await Task.yield()
            }
        }

        let serverEntityIds = Set(payload.entities.map(\.entityId))
        entityRegistry.markMissingEntitiesAsUnavailable(serverEntityIds: serverEntityIds, in: mainContext)

        /**
         Remove Home tiles whose entity is entirely gone from the server. Keyed on
         presence in the sync (not `isAvailable`), so a merely-`"unavailable"` entity
         keeps its tile. A `getStates` failure aborts sync before this point, so
         reaching here implies entities were fetched; the empty-set guard is belt-and-braces.
         */
        HomeTile.pruneOrphaned(keeping: serverEntityIds, in: mainContext)

        // Upsert floors before areas so area→floor links can resolve. Only
        // when the floor fetch succeeded (non-nil) — see `fetchFloorRegistry`.
        var floorsById: [String: FloorEntity] = [:]
        if let floors = payload.floors {
            for floor in floors {
                let entity = FloorEntity.upsert(
                    id: floor.floorId,
                    name: floor.name,
                    level: floor.level,
                    sortOrder: payload.floorSortOrder[floor.floorId] ?? 0,
                    in: mainContext
                )
                floorsById[floor.floorId] = entity
            }
        }

        /**
         Reconcile area membership before reassigning: null out area links for
         entities the server no longer places in any area, so an entity un-assigned
         server-side moves to Unassigned instead of sticking to its old area. Guarded
         on a successful fetch so a transient failure (mappings degraded to []) never
         wipes every link.
         */
        if payload.areaMappingsFetchSucceeded {
            let mappedEntityIds = Set(payload.areaMappings.flatMap(\.entities))
            entityRegistry.clearAreasForEntities(notIn: mappedEntityIds, in: mainContext)
        }

        for (index, mapping) in payload.areaMappings.enumerated() {
            let sortOrder = payload.areaSortOrder[mapping.area_id] ?? index
            let icon = payload.areaIcons[mapping.area_id]
            let area = AreaEntity.upsert(
                id: mapping.area_id,
                name: mapping.area_name,
                icon: icon,
                sortOrder: sortOrder,
                in: mainContext
            )
            // Reassign floor only when the fetch succeeded, so a transient
            // failure never clears existing links. `nil` when the area has no
            // floor or references a floor that no longer exists.
            if payload.floors != nil {
                area.floor = payload.areaFloorIds[mapping.area_id].flatMap { floorsById[$0] }
            }
            for entityId in mapping.entities {
                entityRegistry.assignArea(area, toEntityWithId: entityId, in: mainContext)
            }
            if (index + 1).isMultiple(of: Self.yieldBatchSize) {
                saveBatch("area batch")
                await Task.yield()
            }
        }

        /**
         Prune areas the server no longer has — but only when the fetch
         succeeded, so a transient failure never wipes persisted areas. Deleting
         an area nullifies its inverse entity links, moving them to Unassigned.
         */
        if payload.areaMappingsFetchSucceeded {
            AreaEntity.prune(keeping: Set(payload.areaMappings.map(\.area_id)), in: mainContext)
        }

        // Prune floors the server no longer has — but only when the fetch
        // succeeded, so a transient failure never wipes persisted floors.
        if let floors = payload.floors {
            pruneFloors(keeping: Set(floors.map(\.floorId)))
        }

        for (index, mapping) in payload.deviceMappings.enumerated() {
            entityRegistry.assignDeviceId(mapping.deviceId, toEntityWithId: mapping.entityId, in: mainContext)
            if (index + 1).isMultiple(of: Self.yieldBatchSize) {
                saveBatch("device batch")
                await Task.yield()
            }
        }

        saveBatch("final sync")
    }

    private func pruneFloors(keeping serverFloorIds: Set<String>) {
        guard let stored = try? mainContext.fetch(FetchDescriptor<FloorEntity>()) else { return }
        for floor in stored where !serverFloorIds.contains(floor.floorId) {
            mainContext.delete(floor)
        }
    }

    private func saveBatch(_ label: String) {
        guard mainContext.hasChanges else { return }
        do {
            try mainContext.save()
        } catch {
            Log.error("Failed to save sync batch (\(label))", cause: error)
        }
    }

    // MARK: - Fetch

    private struct SyncPayload {
        let entities: [HAEntity]
        let areaMappings: [AreaMapping]
        let deviceMappings: [DeviceMapping]
        let areaSortOrder: [String: Int]
        let areaIcons: [String: String]
        /**
         Whether the area-mapping fetch succeeded. `false` when the fetch failed
         (and `areaMappings` degraded to `[]`), which suppresses the destructive
         area reconciliation — clearing entity links and pruning area rows — so a
         transient failure never wipes persisted area membership. Mirrors the
         `floors: [FloorRegistryEntry]?` nil-means-failed signal.
         */
        let areaMappingsFetchSucceeded: Bool
        /// Floor registry entries, or `nil` when the floor fetch failed.
        /// `nil` suppresses floor upserts, area→floor reassignment and pruning
        /// so a transient failure never wipes persisted floors.
        let floors: [FloorRegistryEntry]?
        let floorSortOrder: [String: Int]
        /// `areaId → floorId` for areas that Home Assistant assigns to a floor.
        let areaFloorIds: [String: String]
    }

    private func fetchSyncPayload() async throws -> SyncPayload {
        let statesRequest = HATypedRequest<[HAEntity]>(
            request: HARequest(type: .getStates, data: [:])
        )

        async let entitiesTask = conn.send(statesRequest)
        async let areaMappingsTask = restClient.fetchAreaMappings()
        async let deviceMappingsTask = fetchDeviceMappings()
        async let areaRegistryTask = fetchAreaRegistry()
        async let floorRegistryTask = fetchFloorRegistry()

        let (entities, deviceMappings, areaRegistry, floorRegistry) = try await (
            entitiesTask, deviceMappingsTask, areaRegistryTask, floorRegistryTask
        )

        /**
         Degrade area mapping like the other registry fetches: a failure yields
         nil → [] so a transient template error leaves entities rendering ungrouped
         instead of aborting the whole sync. `nil` also distinguishes "fetch failed"
         from "server genuinely has no areas", suppressing the destructive area
         reconciliation (clear + prune) that would otherwise wipe links on failure.
         */
        let fetchedAreaMappings = try? await areaMappingsTask
        let areaMappings = fetchedAreaMappings ?? []

        let areaSortOrder = AreaSortOrderResolver.resolve(areas: areaRegistry, floors: floorRegistry ?? [])
        let floorSortOrder = FloorSortOrderResolver.resolve(floors: floorRegistry ?? [])
        let areaIcons = Dictionary(
            areaRegistry.compactMap { entry in entry.icon.map { (entry.areaId, $0) } },
            uniquingKeysWith: { _, new in new }
        )
        let areaFloorIds = Dictionary(
            areaRegistry.compactMap { entry in entry.floorId.map { (entry.areaId, $0) } },
            uniquingKeysWith: { _, new in new }
        )

        return SyncPayload(
            entities: entities,
            areaMappings: areaMappings,
            deviceMappings: deviceMappings,
            areaSortOrder: areaSortOrder,
            areaIcons: areaIcons,
            areaMappingsFetchSucceeded: fetchedAreaMappings != nil,
            floors: floorRegistry,
            floorSortOrder: floorSortOrder,
            areaFloorIds: areaFloorIds
        )
    }

    // MARK: - Registry Fetching

    /// Fetches entity-to-device mappings from the HA entity registry.
    /// Returns an empty array on failure so sync can proceed without device linking.
    private func fetchDeviceMappings() async -> [DeviceMapping] {
        do {
            let request = HARequest(type: .webSocket("config/entity_registry/list"), data: [:])
            let response = try await conn.send(request)

            guard case let .array(entries) = response else { return [] }

            return entries.compactMap { entry -> DeviceMapping? in
                guard case let .dictionary(dict) = entry,
                      let entityId = dict["entity_id"] as? String,
                      let deviceId = dict["device_id"] as? String
                else { return nil }
                return DeviceMapping(entityId: entityId, deviceId: deviceId)
            }
        } catch {
            Log.error("Failed to fetch entity registry — proceeding without device linking", cause: error)
            return []
        }
    }

    /// Fetches area entries from the HA area registry, preserving registry order.
    /// Returns an empty array on failure so sort order falls back gracefully.
    private func fetchAreaRegistry() async -> [AreaRegistryEntry] {
        do {
            let request = HARequest(type: .webSocket("config/area_registry/list"), data: [:])
            let response = try await conn.send(request)

            guard case let .array(entries) = response else { return [] }

            return entries.compactMap { entry -> AreaRegistryEntry? in
                guard case let .dictionary(dict) = entry,
                      let areaId = dict["area_id"] as? String
                else { return nil }
                let floorId = dict["floor_id"] as? String
                let icon = dict["icon"] as? String
                return AreaRegistryEntry(areaId: areaId, floorId: floorId, icon: icon)
            }
        } catch {
            Log.error("Failed to fetch area registry — proceeding without floor-based ordering", cause: error)
            return []
        }
    }

    /// Fetches floor entries from the HA floor registry.
    ///
    /// Returns `nil` on failure (so callers can distinguish a transient error
    /// from a genuinely empty registry and avoid wiping persisted floors), and
    /// an empty array when Home Assistant simply has no floors defined.
    private func fetchFloorRegistry() async -> [FloorRegistryEntry]? {
        do {
            let request = HARequest(type: .webSocket("config/floor_registry/list"), data: [:])
            let response = try await conn.send(request)

            guard case let .array(entries) = response else { return [] }

            return entries.compactMap { entry -> FloorRegistryEntry? in
                guard case let .dictionary(dict) = entry,
                      let floorId = dict["floor_id"] as? String,
                      let name = dict["name"] as? String
                else { return nil }
                let level = dict["level"] as? Int
                return FloorRegistryEntry(floorId: floorId, name: name, level: level)
            }
        } catch {
            Log.error("Failed to fetch floor registry — keeping existing floors", cause: error)
            return nil
        }
    }

    // MARK: - WebSocket State Subscription

    private func subscribeToStateChanges() {
        stateChangedToken?.cancel()
        Log.info("Subscribing to real-time state changes")
        stateChangedToken = conn.subscribe(to: .stateChanged()) { [weak self] _, event in
            guard let self else { return }

            Task {
                self.handleStateChanged(event)
            }
        }
    }

    private func handleStateChanged(_ event: HAResponseEventStateChanged) {
        guard let entity = event.newState else { return }
        entityRegistry.upsert(from: entity, in: mainContext)
        do {
            try mainContext.save()
        } catch {
            Log.error("Failed to save after state_changed event", cause: error)
        }
    }
}

// MARK: - Localization

private extension HADataSyncService {
    enum Localization {
        static let syncFailed = String(
            localized: "Could not load all data. Some items may be missing.",
            comment: "Toast shown when the initial data sync with Home Assistant fails"
        )
    }
}

/// Maps an entity to its parent device from the HA entity registry.
struct DeviceMapping: Sendable {
    let entityId: String
    let deviceId: String
}
