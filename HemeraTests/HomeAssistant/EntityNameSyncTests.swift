import Foundation
import SwiftData
import Testing
@testable import Hemera

/// The device sensors page names rows from what a full sync stores, so the registry name has to land.
@MainActor
struct EntityNameSyncTests {

    private let container: ModelContainer
    private let service: HADataSyncService

    init() {
        let schema = Schema([SensorEntity.self, BinarySensorEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self])
        container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

        let url = URL(string: "http://localhost:8123")!
        service = HADataSyncService(
            connectionManager: HAConnectionManager(urlProvider: { url }, tokenProvider: { "" }),
            mainContext: container.mainContext,
            entityRegistry: EntityRegistry.shared,
            iconResolver: IconResolver(translations: IconTranslationsFixture.translations),
            onSyncComplete: { _ in }
        )
    }

    @Test func applySyncPayload_setsRegistryNameOnSensorsAndBinarySensors() async {
        let sensor = SensorEntity(entityId: "sensor.robika_filter_left_time", name: "Robika Filter Left Time", state: "146")
        let binary = BinarySensorEntity(entityId: "binary_sensor.robika_mop", name: "Robika Mop Attached", state: .on)
        container.mainContext.insert(sensor)
        container.mainContext.insert(binary)

        await service.applySyncPayload(payload([
            DeviceMapping(entityId: sensor.entityId, deviceId: "robika", entityName: "Filter Left Time"),
            DeviceMapping(entityId: binary.entityId, deviceId: "robika", entityName: "Mop Attached")
        ]))

        #expect(sensor.entityName == "Filter Left Time")
        #expect(binary.entityName == "Mop Attached")
    }

    /// A rename cleared in HA must clear here too, or the old name would stick.
    @Test func applySyncPayload_withoutRegistryName_clearsStoredName() async {
        let sensor = SensorEntity(entityId: "sensor.plug_power", name: "Plug Power", state: "12")
        sensor.entityName = "Old Name"
        container.mainContext.insert(sensor)

        await service.applySyncPayload(payload([DeviceMapping(entityId: sensor.entityId, deviceId: "plug")]))

        #expect(sensor.entityName == nil)
    }

    // MARK: - Helpers

    private func payload(_ deviceMappings: [DeviceMapping]) -> HADataSyncService.SyncPayload {
        HADataSyncService.SyncPayload(
            entities: [],
            areaMappings: [],
            deviceMappings: deviceMappings,
            hiddenEntityIds: nil,
            areaSortOrder: [:],
            areaIcons: [:],
            areaTemperatureEntityIds: [:],
            areaHumidityEntityIds: [:],
            areaMappingsFetchSucceeded: false,
            floors: nil,
            floorSortOrder: [:],
            areaFloorIds: [:],
            iconTranslations: nil
        )
    }
}
