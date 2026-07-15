import Foundation
import SwiftData
import Testing
@testable import Hemera

@MainActor
struct DeviceIdAssignmentTests {

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

        EntityRegistry.shared.register(SensorEntity.self)
        EntityRegistry.shared.register(SwitchEntity.self)
        EntityRegistry.shared.register(LightEntity.self)
    }

    @Test
    func assignDeviceId_assignsToCorrectEntity() {
        let sensor = SensorEntity(entityId: "sensor.power", name: "Power", state: "100")
        context.insert(sensor)

        EntityRegistry.shared.assignDeviceId("device_1", toEntityWithId: "sensor.power", in: context)

        #expect(sensor.deviceId == "device_1")
    }

    @Test
    func assignDeviceId_unregisteredEntityId_silentlySkips() {
        EntityRegistry.shared.assignDeviceId("device_1", toEntityWithId: "sensor.nonexistent", in: context)
        // No crash — test passes if we get here
    }

    @Test
    func assignDeviceId_emptyMappings_noChanges() {
        let sensor = SensorEntity(entityId: "sensor.power", name: "Power", state: "100")
        context.insert(sensor)

        // No assignments
        #expect(sensor.deviceId == nil)
    }

    @Test
    func assignDeviceIdIfMatch_returnsTrueWhenFound() {
        let sw = SwitchEntity(entityId: "switch.plug", name: "Plug", state: .on)
        context.insert(sw)

        let result = SwitchEntity.assignDeviceIdIfMatch("device_1", entityId: "switch.plug", in: context)
        #expect(result == true)
        #expect(sw.deviceId == "device_1")
    }

    @Test
    func assignDeviceIdIfMatch_returnsFalseWhenNotFound() {
        let result = SwitchEntity.assignDeviceIdIfMatch("device_1", entityId: "switch.missing", in: context)
        #expect(result == false)
    }
}
