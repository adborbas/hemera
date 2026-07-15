import Foundation
import SwiftData
import HAKit
import Testing
@testable import Hemera

@MainActor
struct UnavailabilityTests {

    let container: ModelContainer
    let context: ModelContext

    init() {
        let schema = Schema([
            LightEntity.self, CoverEntity.self, SceneEntity.self,
            SensorEntity.self, SwitchEntity.self, BinarySensorEntity.self,
            ButtonEntity.self, AutomationEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext

        EntityRegistry.shared.register(LightEntity.self)
        EntityRegistry.shared.register(SwitchEntity.self)
        EntityRegistry.shared.register(SensorEntity.self)
    }

    // MARK: - markMissingAsUnavailable

    @Test
    func markMissing_entityNotInServerResponse_becomesUnavailable() {
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .on)
        context.insert(light)

        LightEntity.markMissingAsUnavailable(serverEntityIds: [], in: context)

        #expect(light.isAvailable == false)
    }

    @Test
    func markMissing_entityInServerResponse_staysAvailable() {
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .on)
        context.insert(light)

        LightEntity.markMissingAsUnavailable(serverEntityIds: ["light.lamp"], in: context)

        #expect(light.isAvailable == true)
    }

    @Test
    func markMissing_mixedEntities_onlyMissingMarked() {
        let lamp = LightEntity(entityId: "light.lamp", name: "Lamp", state: .on)
        let desk = LightEntity(entityId: "light.desk", name: "Desk", state: .off)
        context.insert(lamp)
        context.insert(desk)

        LightEntity.markMissingAsUnavailable(serverEntityIds: ["light.lamp"], in: context)

        #expect(lamp.isAvailable == true)
        #expect(desk.isAvailable == false)
    }

    // MARK: - Upsert re-marks as available

    @Test
    func upsert_previouslyUnavailableEntity_becomesAvailable() throws {
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .off)
        light.isAvailable = false
        context.insert(light)

        let haEntity = try HAEntity(
            entityId: "light.lamp",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["friendly_name": "Lamp"],
            context: .init(id: "", userId: nil, parentId: nil)
        )
        LightEntity.performUpsert(in: context, from: haEntity)

        #expect(light.isAvailable == true)
    }

    @Test
    func upsert_newEntity_isAvailable() throws {
        let haEntity = try HAEntity(
            entityId: "light.new",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["friendly_name": "New Light"],
            context: .init(id: "", userId: nil, parentId: nil)
        )
        LightEntity.performUpsert(in: context, from: haEntity)

        let fetched = LightEntity.fetch(byId: "light.new", in: context)
        #expect(fetched?.isAvailable == true)
    }

    // MARK: - Registry-level dispatch

    @Test
    func registryMarkMissing_dispatchesToAllTypes() {
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .on)
        let sensor = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "22")
        context.insert(light)
        context.insert(sensor)

        // Only the sensor entityId is in the server response
        EntityRegistry.shared.markMissingEntitiesAsUnavailable(
            serverEntityIds: ["sensor.temp"],
            in: context
        )

        #expect(light.isAvailable == false)
        #expect(sensor.isAvailable == true)
    }

    // MARK: - Default value

    @Test
    func newEntity_defaultsToAvailable() {
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .on)
        #expect(light.isAvailable == true)
    }
}
