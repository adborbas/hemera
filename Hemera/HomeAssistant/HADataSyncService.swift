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
    private let mainContext: ModelContext
    private let entityRegistry: EntityRegistry
    private let errorNotifier: ErrorNotifier?
    private let iconResolver: IconResolver
    private let onSyncComplete: @MainActor () -> Void

    private var stateChangedToken: HACancellable?

    /**
     Guards the real-time path until the initial snapshot has been applied.
     While `false`, incoming `state_changed` events are buffered instead of
     applied, so a change that fires during the snapshot-fetch window is
     reconciled against the snapshot rather than lost.
     */
    private var isSnapshotApplied = false

    /**
     Events received before the snapshot was applied, kept in arrival order.
     A plain array is safe: the service is `@MainActor` and HAKit delivers
     the subscription callback on `.main` (`connection.callbackQueue = .main`).
     */
    private var bufferedEvents: [HAResponseEventStateChanged] = []

    /**
     Cap on `bufferedEvents` so a stalled sync (live socket, but a `getStates`
     that never returns) can't grow the buffer without bound. Past the cap the
     oldest events are dropped; the snapshot re-baselines every entity on
     flush, so only intermediate states of a fast-changing entity during the
     stall are lost.
     */
    static let maxBufferedEvents = 2000

    /// Ensures the buffer-overflow warning is logged once per sync window, not
    /// once per dropped event.
    private var didWarnBufferOverflow = false

    deinit { stateChangedToken?.cancel() }

    private var conn: HAConnection { connectionManager.connection }

    init(
        connectionManager: HAConnectionManager,
        mainContext: ModelContext,
        entityRegistry: EntityRegistry,
        errorNotifier: ErrorNotifier? = nil,
        iconResolver: IconResolver,
        onSyncComplete: @MainActor @escaping () -> Void
    ) {
        self.connectionManager = connectionManager
        self.mainContext = mainContext
        self.entityRegistry = entityRegistry
        self.errorNotifier = errorNotifier
        self.iconResolver = iconResolver
        self.onSyncComplete = onSyncComplete
    }

    func start() {
        Log.info("Starting initial data sync")
        /**
         Subscribe before fetching the snapshot so events firing during the
         fetch window are buffered (not lost) and flushed once it lands.
         */
        subscribeToStateChanges()
        Task { await syncAllData() }
    }

    /// Re-fetches all data and re-subscribes to real-time changes (e.g. after reconnecting or pull-to-refresh).
    func resync() async {
        Log.info("Re-syncing all data")
        /**
         Re-arm buffering for the resync window, then re-subscribe before the
         fetch so events during the window are reconciled against the snapshot
         (closing the same gap as `start()`, e.g. on reconnect).

         Tradeoff: live updates are held — not applied — until the snapshot
         lands and flushes, so a foreground / pull-to-refresh resync briefly
         pauses live UI updates instead of showing them immediately. This is
         bounded and self-healing: nothing is lost and arrival order is
         preserved on flush.
         */
        isSnapshotApplied = false
        subscribeToStateChanges()
        await syncAllData()
    }

    // MARK: - Data Sync

    private func syncAllData() async {
        do {
            let payload = try await fetchSyncPayload()
            Log.info("Fetched \(payload.entities.count) entities, \(payload.areaMappings.count) areas, \(payload.floors?.count ?? 0) floors — applying to main context")

            await applySyncPayload(payload)
            flushBufferedEvents()

            errorNotifier?.clearSyncFailed()
            Log.info("Sync complete")
            onSyncComplete()
        } catch {
            Log.error("Failed to sync data", cause: error)
            /**
             Flush even on failure so buffered events are applied and the
             buffer can never grow unbounded across repeated failed syncs.
             */
            flushBufferedEvents()
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
    /// Step order is load-bearing: entities, then floors, then the areas linking to them, then prunes.
    func applySyncPayload(_ payload: SyncPayload) async {
        if let iconTranslations = payload.iconTranslations {
            iconResolver.update(iconTranslations)
        }

        await applyEntities(payload)
        let floorsById = applyFloors(payload)
        await applyAreas(payload, floorsById: floorsById)
        applyPrunes(payload)
        await applyDeviceMappings(payload)

        saveBatch("final sync")
    }

    private func applyEntities(_ payload: SyncPayload) async {
        for (index, entity) in payload.entities.enumerated() {
            entityRegistry.upsert(from: entity, in: mainContext)
            if (index + 1).isMultiple(of: Self.yieldBatchSize) {
                saveBatch("entity batch")
                await Task.yield()
            }
        }

        let serverEntityIds = Set(payload.entities.map(\.entityId))
        entityRegistry.markMissingEntitiesAsUnavailable(serverEntityIds: serverEntityIds, in: mainContext)

        // Apply Home Assistant's own hidden flag only when the registry fetch
        // succeeded, so a transient failure never clears persisted HA-hidden state.
        if let hiddenEntityIds = payload.hiddenEntityIds {
            entityRegistry.applyHAHidden(hiddenEntityIds, in: mainContext)
        }

        /**
         Remove Home tiles whose entity is entirely gone from the server. Keyed on
         presence in the sync (not `isAvailable`), so a merely-`"unavailable"` entity
         keeps its tile. A `getStates` failure aborts sync before this point, so
         reaching here implies entities were fetched; the empty-set guard is belt-and-braces.
         */
        HomeTile.pruneOrphaned(keeping: serverEntityIds, in: mainContext)
    }

    /// Returns the lookup area→floor links resolve through. Skipped when the fetch failed.
    private func applyFloors(_ payload: SyncPayload) -> [String: FloorEntity] {
        guard let floors = payload.floors else { return [:] }

        var floorsById: [String: FloorEntity] = [:]
        for floor in floors {
            floorsById[floor.floorId] = FloorEntity.upsert(
                id: floor.floorId,
                name: floor.name,
                level: floor.level,
                sortOrder: payload.floorSortOrder[floor.floorId] ?? 0,
                in: mainContext
            )
        }
        return floorsById
    }

    private func applyAreas(_ payload: SyncPayload, floorsById: [String: FloorEntity]) async {
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
            let area = AreaEntity.upsert(
                id: mapping.areaId,
                name: mapping.areaName,
                icon: payload.areaIcons[mapping.areaId],
                sortOrder: payload.areaSortOrder[mapping.areaId] ?? index,
                in: mainContext
            )
            // Reassign floor only when the fetch succeeded, so a transient
            // failure never clears existing links. `nil` when the area has no
            // floor or references a floor that no longer exists.
            if payload.floors != nil {
                area.floor = payload.areaFloorIds[mapping.areaId].flatMap { floorsById[$0] }
            }
            for entityId in mapping.entities {
                entityRegistry.assignArea(area, toEntityWithId: entityId, in: mainContext)
            }
            if (index + 1).isMultiple(of: Self.yieldBatchSize) {
                saveBatch("area batch")
                await Task.yield()
            }
        }
    }

    private func applyPrunes(_ payload: SyncPayload) {
        /**
         Prune areas the server no longer has — but only when the fetch
         succeeded, so a transient failure never wipes persisted areas. Deleting
         an area nullifies its inverse entity links, moving them to Unassigned.
         */
        if payload.areaMappingsFetchSucceeded {
            AreaEntity.prune(keeping: Set(payload.areaMappings.map(\.areaId)), in: mainContext)
        }

        // Prune floors the server no longer has — but only when the fetch
        // succeeded, so a transient failure never wipes persisted floors.
        if let floors = payload.floors {
            pruneFloors(keeping: Set(floors.map(\.floorId)))
        }
    }

    private func applyDeviceMappings(_ payload: SyncPayload) async {
        for (index, mapping) in payload.deviceMappings.enumerated() {
            entityRegistry.assignDeviceId(mapping.deviceId, toEntityWithId: mapping.entityId, in: mainContext)
            if (index + 1).isMultiple(of: Self.yieldBatchSize) {
                saveBatch("device batch")
                await Task.yield()
            }
        }
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

    struct SyncPayload {
        let entities: [HAEntity]
        let areaMappings: [AreaMapping]
        let deviceMappings: [DeviceMapping]
        /// Entity IDs Home Assistant marks hidden (`hidden_by`), or `nil` when the
        /// entity-registry fetch failed — `nil` skips applying so a transient
        /// failure never clears persisted HA-hidden state.
        let hiddenEntityIds: Set<String>?
        let areaSortOrder: [String: Int]
        let areaIcons: [String: String]
        /**
         Whether every registry the mapping derives from was fetched. `false` suppresses clearing
         entity links and pruning areas, so a transient failure never wipes stored membership.
        */
        let areaMappingsFetchSucceeded: Bool
        /// Floor registry entries, or `nil` when the floor fetch failed.
        /// `nil` suppresses floor upserts, area→floor reassignment and pruning
        /// so a transient failure never wipes persisted floors.
        let floors: [FloorRegistryEntry]?
        let floorSortOrder: [String: Int]
        /// `areaId → floorId` for areas that Home Assistant assigns to a floor.
        let areaFloorIds: [String: String]
        /// Home Assistant's icon translations, or `nil` when neither the server nor the cache had any.
        let iconTranslations: IconTranslations?
    }

    private func fetchSyncPayload() async throws -> SyncPayload {
        let statesRequest = HATypedRequest<[HAEntity]>(
            request: HARequest(type: .getStates, data: [:])
        )

        async let entitiesTask = conn.send(statesRequest)
        async let entityRegistryTask = fetchEntityRegistry()
        async let areaRegistryTask = fetchAreaRegistry()
        async let deviceRegistryTask = fetchDeviceRegistry()
        async let floorRegistryTask = fetchFloorRegistry()
        async let iconTranslationsTask = fetchIconTranslations()

        let (entities, entityRegistryResult, areaRegistry, deviceRegistry, floorRegistry, iconTranslations) = try await (
            entitiesTask, entityRegistryTask, areaRegistryTask, deviceRegistryTask, floorRegistryTask, iconTranslationsTask
        )
        let deviceMappings = entityRegistryResult?.deviceMappings ?? []
        let hiddenEntityIds = entityRegistryResult?.hiddenEntityIds

        /**
         Membership comes from registries every Home Assistant user can read. A failed fetch yields
         no mapping and reports failure, so the reconciliation below leaves stored membership alone.
        */
        let areaMappingsFetchSucceeded = areaRegistry != nil && entityRegistryResult != nil && deviceRegistry != nil
        let areaMappings = AreaMappingResolver.resolve(
            areas: areaRegistry ?? [],
            entityAreaIds: entityRegistryResult?.entityAreaIds ?? [:],
            deviceMappings: deviceMappings,
            devices: deviceRegistry ?? []
        )

        let areaSortOrder = AreaSortOrderResolver.resolve(areas: areaRegistry ?? [], floors: floorRegistry ?? [])
        let floorSortOrder = FloorSortOrderResolver.resolve(floors: floorRegistry ?? [])
        let areaIcons = Dictionary(
            (areaRegistry ?? []).compactMap { entry in entry.icon.map { (entry.areaId, $0) } },
            uniquingKeysWith: { _, new in new }
        )
        let areaFloorIds = Dictionary(
            (areaRegistry ?? []).compactMap { entry in entry.floorId.map { (entry.areaId, $0) } },
            uniquingKeysWith: { _, new in new }
        )

        return SyncPayload(
            entities: entities,
            areaMappings: areaMappings,
            deviceMappings: deviceMappings,
            hiddenEntityIds: hiddenEntityIds,
            areaSortOrder: areaSortOrder,
            areaIcons: areaIcons,
            areaMappingsFetchSucceeded: areaMappingsFetchSucceeded,
            floors: floorRegistry,
            floorSortOrder: floorSortOrder,
            areaFloorIds: areaFloorIds,
            iconTranslations: iconTranslations
        )
    }

    // MARK: - Icon Translations

    /**
     Domains whose icon translations Hemera actually renders. Passed explicitly because omitting
     `integration` makes Home Assistant return every loaded component, and `sensor` alone is ~10 KB
     of device classes we never draw a card for.
    */
    private static let iconTranslationDomains = [
        "light", "switch", "cover", "climate", "binary_sensor",
        "scene", "script", "automation", "button"
    ]

    /**
     Fetches Home Assistant's icon translations.

     Returns `nil` on failure so the resolver keeps what it already has — the bundled seed at worst —
     rather than blanking every icon on a transient error.
    */
    private func fetchIconTranslations() async -> IconTranslations? {
        do {
            let request = HARequest(
                type: .webSocket("frontend/get_icons"),
                data: ["category": "entity_component", "integration": Self.iconTranslationDomains]
            )
            let response = try await conn.send(request)

            guard let translations = IconTranslations(haData: response) else {
                Log.warning("frontend/get_icons returned no usable icon translations — keeping current map")
                return nil
            }
            return translations
        } catch {
            Log.error("Failed to fetch icon translations — keeping current map", cause: error)
            return nil
        }
    }

    // MARK: - Registry Fetching

    /// `nil` on failure, so a transient error never clears persisted HA-hidden state.
    private func fetchEntityRegistry() async -> EntityRegistrySnapshot? {
        do {
            let request = HARequest(type: .webSocket("config/entity_registry/list"), data: [:])
            return EntityRegistrySnapshot.decode(try await conn.send(request))
        } catch {
            Log.error("Failed to fetch entity registry — proceeding without device linking or HA-hidden filtering", cause: error)
            return nil
        }
    }

    /// Preserves registry order. `nil` on failure: `[]` would read as "no areas" and prune every stored one.
    private func fetchAreaRegistry() async -> [AreaRegistryEntry]? {
        do {
            let request = HARequest(type: .webSocket("config/area_registry/list"), data: [:])
            return AreaRegistryEntry.decodeList(try await conn.send(request))
        } catch {
            Log.error("Failed to fetch area registry — keeping existing areas", cause: error)
            return nil
        }
    }

    /// `nil` on failure, so entities keep the area membership their device gave them.
    private func fetchDeviceRegistry() async -> [DeviceRegistryEntry]? {
        do {
            let request = HARequest(type: .webSocket("config/device_registry/list"), data: [:])
            return DeviceRegistryEntry.decodeList(try await conn.send(request))
        } catch {
            Log.error("Failed to fetch device registry — proceeding without device-inherited areas", cause: error)
            return nil
        }
    }

    /// `[]` means no floors and prunes every stored one, so a failure must report `nil` instead.
    private func fetchFloorRegistry() async -> [FloorRegistryEntry]? {
        do {
            let request = HARequest(type: .webSocket("config/floor_registry/list"), data: [:])
            return FloorRegistryEntry.decodeList(try await conn.send(request))
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

            /**
             HAKit delivers this callback synchronously on `.main`
             (`connection.callbackQueue = .main`), so handle it in delivery
             order. A per-event `Task` would drop HAKit's serial ordering
             guarantee and could apply back-to-back changes for one entity out
             of order — and would also race the buffer flush.
             */
            MainActor.assumeIsolated {
                self.handleStateChanged(event)
            }
        }
    }

    func handleStateChanged(_ event: HAResponseEventStateChanged) {
        guard isSnapshotApplied else {
            bufferedEvents.append(event)
            if bufferedEvents.count > Self.maxBufferedEvents {
                bufferedEvents.removeFirst()
                if !didWarnBufferOverflow {
                    didWarnBufferOverflow = true
                    Log.warning("state_changed buffer exceeded \(Self.maxBufferedEvents) events during sync — dropping oldest; snapshot will re-baseline on completion")
                }
            }
            return
        }
        applyStateChanged(event)
    }

    /**
     Applies events buffered during the snapshot-fetch window in arrival
     order (preserving last-writer-wins), then switches to applying
     subsequent events immediately.
     */
    func flushBufferedEvents() {
        isSnapshotApplied = true
        didWarnBufferOverflow = false
        let pending = bufferedEvents
        bufferedEvents.removeAll()
        for event in pending {
            applyStateChanged(event)
        }
    }

    private func applyStateChanged(_ event: HAResponseEventStateChanged) {
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
