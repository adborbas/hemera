import Foundation
import SwiftData
import Testing
@testable import Hemera

/**
 Tests the area-membership reconciliation the sync path performs after fetching area
 mappings: clearing links for entities the server no longer places in any area, and
 pruning `AreaEntity` rows for areas deleted server-side.

 These exercise the same helpers `HADataSyncService.applySyncPayload` calls — guarded
 there on a successful area-mapping fetch — without needing a live connection.
 */
@MainActor
struct AreaReconciliationTests {

    let container: ModelContainer
    let context: ModelContext

    init() {
        let schema = Schema([
            LightEntity.self, SwitchEntity.self, CoverEntity.self,
            SensorEntity.self, BinarySensorEntity.self, SceneEntity.self,
            ButtonEntity.self, AutomationEntity.self, ClimateEntity.self,
            AreaEntity.self, FloorEntity.self, HomeTile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext

        EntityRegistry.shared.register(LightEntity.self)
        EntityRegistry.shared.register(SwitchEntity.self)
    }

    // MARK: - clearAreasForEntities (sticky-area membership)

    @Test
    func clearAreas_entityDroppedFromAllMappings_movesToUnassigned() {
        let kitchen = AreaEntity(areaId: "kitchen", name: "Kitchen")
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .on)
        light.area = kitchen
        context.insert(kitchen)
        context.insert(light)

        // Server now maps no entities into any area.
        EntityRegistry.shared.clearAreasForEntities(notIn: [], in: context)

        #expect(light.area == nil)
    }

    @Test
    func clearAreas_entityStillMapped_keepsArea() {
        let kitchen = AreaEntity(areaId: "kitchen", name: "Kitchen")
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .on)
        light.area = kitchen
        context.insert(kitchen)
        context.insert(light)

        EntityRegistry.shared.clearAreasForEntities(notIn: ["light.lamp"], in: context)

        #expect(light.area?.areaId == "kitchen")
    }

    @Test
    func clearAreas_mixedEntities_onlyDroppedCleared() {
        let kitchen = AreaEntity(areaId: "kitchen", name: "Kitchen")
        let lamp = LightEntity(entityId: "light.lamp", name: "Lamp", state: .on)
        let plug = SwitchEntity(entityId: "switch.plug", name: "Plug", state: .on, deviceClass: .outlet)
        lamp.area = kitchen
        plug.area = kitchen
        context.insert(kitchen)
        context.insert(lamp)
        context.insert(plug)

        // Only the lamp remains mapped into an area.
        EntityRegistry.shared.clearAreasForEntities(notIn: ["light.lamp"], in: context)

        #expect(lamp.area?.areaId == "kitchen")
        #expect(plug.area == nil)
    }

    // MARK: - AreaEntity.prune (stale area rows)

    @Test
    func prune_areaAbsentFromServer_isDeleted() throws {
        context.insert(AreaEntity(areaId: "kitchen", name: "Kitchen"))
        context.insert(AreaEntity(areaId: "garage", name: "Garage"))

        AreaEntity.prune(keeping: ["kitchen"], in: context)

        let remaining = try context.fetch(FetchDescriptor<AreaEntity>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.areaId == "kitchen")
    }

    @Test
    func prune_deletedArea_nullifiesEntityRelationship() throws {
        let garage = AreaEntity(areaId: "garage", name: "Garage")
        let light = LightEntity(entityId: "light.g", name: "G", state: .on)
        light.area = garage
        context.insert(garage)
        context.insert(light)

        AreaEntity.prune(keeping: [], in: context)
        try context.save()

        #expect(light.area == nil)
        #expect(try context.fetch(FetchDescriptor<AreaEntity>()).isEmpty)
    }

    @Test
    func prune_allAreasStillPresent_deletesNothing() throws {
        context.insert(AreaEntity(areaId: "kitchen", name: "Kitchen"))
        context.insert(AreaEntity(areaId: "garage", name: "Garage"))

        AreaEntity.prune(keeping: ["kitchen", "garage"], in: context)

        #expect(try context.fetch(FetchDescriptor<AreaEntity>()).count == 2)
    }
}
