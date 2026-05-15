import Foundation
import SwiftData
import HAKit
import Testing
@testable import Hemera

/// Tests the real-time state update path: mainContext upsert → @Model mutation → VM reflects change.
///
/// This exercises the same code as `HADataSyncService.handleStateChanged` without requiring
/// a WebSocket connection — `EntityRegistry.shared.upsert(from:, in:)` is called directly.
@MainActor
struct StateUpdatePropagationTests {

    let container: ModelContainer
    let context: ModelContext

    init() {
        let schema = Schema([
            LightEntity.self, SwitchEntity.self, CoverEntity.self,
            BinarySensorEntity.self, SensorEntity.self, SceneEntity.self,
            ButtonEntity.self, AutomationEntity.self, ClimateEntity.self,
            AreaEntity.self, HomeTile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext

        EntityRegistry.shared.register(LightEntity.self)
        EntityRegistry.shared.register(SwitchEntity.self)
        EntityRegistry.shared.register(SensorEntity.self)
    }

    // MARK: - Light

    @Test
    func upsertOnMainContext_updatesLightViewModel() throws {
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .off)
        context.insert(light)

        let vm = LightCardViewModel(light: light, controller: MockController())
        #expect(!vm.isOn)
        #expect(vm.brightness == 0)

        let haEntity = try HAEntity(
            entityId: "light.lamp",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["friendly_name": "Lamp", "brightness": 200],
            context: .init(id: "", userId: nil, parentId: nil)
        )

        EntityRegistry.shared.upsert(from: haEntity, in: context)

        #expect(vm.isOn)
        #expect(vm.brightness == 200)
    }

    // MARK: - Switch

    @Test
    func upsertOnMainContext_updatesSwitchViewModel() throws {
        let sw = SwitchEntity(entityId: "switch.plug", name: "Plug", state: .off, deviceClass: .outlet)
        context.insert(sw)

        let vm = SwitchCardViewModel(switchEntity: sw, controller: MockController())
        #expect(!vm.isOn)

        let haEntity = try HAEntity(
            entityId: "switch.plug",
            domain: "switch",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["friendly_name": "Plug", "device_class": "outlet"],
            context: .init(id: "", userId: nil, parentId: nil)
        )

        EntityRegistry.shared.upsert(from: haEntity, in: context)

        #expect(vm.isOn)
    }

    // MARK: - Area Status Icons

    @Test
    func upsertOnMainContext_updatesAreaStatusIcon() throws {
        let area = AreaEntity(areaId: "area.living", name: "Living Room")
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .off)
        light.area = area
        context.insert(area)
        context.insert(light)

        let iconsBefore = AreaDisplayHelpers.statusIcons(from: area)
        #expect(iconsBefore.first?.isActive == false)

        let haEntity = try HAEntity(
            entityId: "light.lamp",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["friendly_name": "Lamp"],
            context: .init(id: "", userId: nil, parentId: nil)
        )

        EntityRegistry.shared.upsert(from: haEntity, in: context)

        let iconsAfter = AreaDisplayHelpers.statusIcons(from: area)
        #expect(iconsAfter.first?.isActive == true)
    }

    // MARK: - Area Climate Data

    @Test
    func upsertOnMainContext_updatesAreaClimateData() throws {
        let area = AreaEntity(areaId: "area.kitchen", name: "Kitchen")
        let sensor = SensorEntity(entityId: "sensor.temp", name: "Temperature", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C")
        sensor.area = area
        context.insert(area)
        context.insert(sensor)

        let (tempBefore, _) = AreaDisplayHelpers.climateSummary(from: area.sensors)
        #expect(tempBefore == "21°C")

        let haEntity = try HAEntity(
            entityId: "sensor.temp",
            domain: "sensor",
            state: "24",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["friendly_name": "Temperature", "device_class": "temperature", "unit_of_measurement": "°C"],
            context: .init(id: "", userId: nil, parentId: nil)
        )

        EntityRegistry.shared.upsert(from: haEntity, in: context)

        let (tempAfter, _) = AreaDisplayHelpers.climateSummary(from: area.sensors)
        #expect(tempAfter == "24°C")
    }
}
