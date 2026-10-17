import Foundation
import HAKit
import Testing
@testable import Hemera

@MainActor
struct BinarySensorEntityTests {

    private func haEntity(deviceClass: String?) throws -> HAEntity {
        var attributes: [String: Any] = ["friendly_name": "Sensor"]
        if let deviceClass { attributes["device_class"] = deviceClass }
        return try HAEntity(
            entityId: "binary_sensor.test",
            domain: "binary_sensor",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: attributes,
            context: .init(id: "", userId: nil, parentId: nil)
        )
    }

    @Test func update_modelledDeviceClass_populatesBothEnumAndRaw() throws {
        let sensor = BinarySensorEntity(entityId: "binary_sensor.test")
        sensor.update(from: try haEntity(deviceClass: "motion"))

        #expect(sensor.deviceClass == .motion)
        #expect(sensor.deviceClassRaw == "motion")
    }

    /**
     The enum covers 6 of Home Assistant's ~30 binary sensor classes. Icon resolution reads the raw
     string, so an unmodelled class must still survive the sync — otherwise every moisture, battery
     or tamper sensor silently falls back to the generic domain icon, which is the lossiness this
     whole change exists to remove.
    */
    @Test func update_unmodelledDeviceClass_preservesRawStringDespiteUnknownEnum() throws {
        let sensor = BinarySensorEntity(entityId: "binary_sensor.test")
        sensor.update(from: try haEntity(deviceClass: "moisture"))

        #expect(sensor.deviceClass == .unknown)
        #expect(sensor.deviceClassRaw == "moisture")
    }

    @Test func update_withoutDeviceClass_clearsRaw() throws {
        let sensor = BinarySensorEntity(entityId: "binary_sensor.test", name: "S", state: .on, deviceClass: .motion)
        sensor.update(from: try haEntity(deviceClass: nil))

        #expect(sensor.deviceClass == .unknown)
        #expect(sensor.deviceClassRaw == nil)
    }

    @Test func init_derivesRawFromDeviceClassWhenNotGiven() {
        let sensor = BinarySensorEntity(entityId: "binary_sensor.test", name: "S", state: .on, deviceClass: .door)
        #expect(sensor.deviceClassRaw == "door")
    }

    @Test func init_unknownDeviceClass_leavesRawNil() {
        let sensor = BinarySensorEntity(entityId: "binary_sensor.test", name: "S", state: .on)
        #expect(sensor.deviceClassRaw == nil)
    }
}
