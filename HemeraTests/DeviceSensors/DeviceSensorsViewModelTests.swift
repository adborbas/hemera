import Foundation
import SwiftData
import Testing
@testable import Hemera

@MainActor
struct DeviceSensorsViewModelTests {

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() {
        let schema = Schema([SensorEntity.self, BinarySensorEntity.self, AreaEntity.self])
        container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    // MARK: - Which sensors

    @Test func rows_onlyListsTheDevicesOwnSensorsAndBinarySensors() {
        insertSensor("sensor.robika_battery", name: "Battery Level", state: "100", unit: "%")
        insertSensor("sensor.plug_power", name: "Power", state: "12", unit: "W", deviceId: "plug")
        insertBinarySensor("binary_sensor.robika_charging", name: "Charging", deviceClass: .batteryCharging)

        #expect(makeViewModel().rows.map(\.id) == ["sensor.robika_battery", "binary_sensor.robika_charging"])
    }

    /// Hiding in HA means "don't show me this"; hiding in Hemera only tidies an area page.
    @Test func rows_skipHiddenInHA_keepHiddenInHemera() {
        insertSensor("sensor.robika_ha_hidden", name: "A", state: "1").isHiddenInHA = true
        insertSensor("sensor.robika_area_hidden", name: "B", state: "1").isHidden = true

        #expect(makeViewModel().rows.map(\.id) == ["sensor.robika_area_hidden"])
    }

    @Test func hasSensors_falseWhenOnlyHAHiddenSensors_soTheInfoButtonHides() {
        insertSensor("sensor.robika_ha_hidden", name: "A", state: "1").isHiddenInHA = true

        #expect(makeViewModel().hasSensors == false)
    }

    // MARK: - Names and order

    /// HA's device page names entities without the device, so "Robika" must not lead every row.
    @Test func rows_preferRegistryNameOverFriendlyName() {
        insertSensor("sensor.robika_filter", name: "Robika Filter Filter Left Time", state: "146", unit: "h")
            .entityName = "Filter Filter Left Time"

        #expect(makeViewModel().rows.map(\.name) == ["Filter Filter Left Time"])
    }

    /// A leading space from the integration would indent the row's first line only.
    @Test func rows_trimSpacesAroundNames() {
        insertSensor("sensor.robika_fault", name: "Robika Fault Ids", state: "0").entityName = " Robot Cleaner Fault Ids "

        #expect(makeViewModel().rows.first?.name == "Robot Cleaner Fault Ids")
    }

    @Test func rows_sortedAToZByName() {
        insertSensor("sensor.robika_c", name: "charging state", state: "charging")
        insertSensor("sensor.robika_a", name: "Battery Voltage", state: "14")
        insertSensor("sensor.robika_b", name: "Brush Cleaner", state: "3")

        #expect(makeViewModel().rows.map(\.name) == ["Battery Voltage", "Brush Cleaner", "charging state"])
    }

    // MARK: - Values

    @Test func value_percentHasNoSpace_otherUnitsDo() {
        insertSensor("sensor.robika_level", name: "Level", state: "96", unit: "%")
        insertSensor("sensor.robika_time", name: "Time", state: "58", unit: "h")

        #expect(makeViewModel().rows.map(\.value) == ["96%", "58 h"])
    }

    /// Raw state, only the separator localised: no rounding hides or invents precision.
    @Test func value_usesLocaleDecimalSeparatorWithoutRounding() {
        insertSensor("sensor.plug_power", name: "Power", state: "12.3456", unit: "W")

        #expect(makeViewModel(locale: Locale(identifier: "hu_HU")).rows.first?.value == "12,3456 W")
    }

    @Test func value_unknownAndUnavailable_areShownNotHidden() {
        insertSensor("sensor.robika_a", name: "A", state: "unknown", unit: "%")
        insertSensor("sensor.robika_b", name: "B", state: "unavailable", unit: "%")
        insertSensor("sensor.robika_c", name: "C", state: "5", unit: "%").isAvailable = false

        #expect(makeViewModel().rows.map(\.value) == ["Unknown", "Unavailable", "Unavailable"])
        #expect(makeViewModel().rows.allSatisfy { $0.percent == nil })
    }

    @Test func value_text_capitalisesOnlyTheFirstLetter() {
        insertSensor("sensor.robika_last", name: "Last", state: "cleaned 42 m² in 38 min")

        #expect(makeViewModel().rows.first?.value == "Cleaned 42 m² in 38 min")
    }

    @Test func value_binarySensor_usesItsDeviceClassWording() {
        insertBinarySensor("binary_sensor.robika_charging", name: "Charging", deviceClass: .batteryCharging)

        #expect(makeViewModel().rows.first?.value == "Charging")
    }

    /// A binary sensor gone from the last sync keeps its old state; showing it would claim a reading.
    @Test func value_binarySensorMissingFromSync_isUnavailable() {
        insertBinarySensor("binary_sensor.robika_charging", name: "Charging", deviceClass: .batteryCharging)
            .isAvailable = false

        #expect(makeViewModel().rows.first?.value == "Unavailable")
    }

    /// "nan", "inf" and hex parse as `Double`; treating them as numbers would draw a NaN-wide bar.
    @Test(arguments: ["nan", "inf", "0x1A"])
    func value_numberLookalikes_areText(_ state: String) {
        insertSensor("sensor.robika_odd", name: "Odd", state: state, unit: "%")

        #expect(makeViewModel().rows.first?.percent == nil)
        #expect(makeViewModel().rows.first?.value.hasSuffix("%") == false)
    }

    // MARK: - Pairing

    @Test func rows_pairPercentAndTimeOfTheSamePart() {
        insertSensor("sensor.robika_filter_level", name: "Filter Life Level", state: "98", unit: "%")
        insertSensor("sensor.robika_filter_time", name: "Filter Left Time", state: "146", unit: "h")

        let rows = makeViewModel().rows
        #expect(rows.count == 1)
        #expect(rows.first?.name == "Filter")
        #expect(rows.first?.value == "98%")
        #expect(rows.first?.percent == 98)
        #expect(rows.first?.timeLeft == "146 h")
    }

    /// Two parts sharing a name (main and side brush) pair in entity-id order rather than guessing.
    @Test func rows_ambiguousParts_pairInEntityIdOrder() {
        insertSensor("sensor.robika_brush_2_level", name: "Brush Life Level", state: "80", unit: "%")
        insertSensor("sensor.robika_brush_1_level", name: "Brush Life Level", state: "99", unit: "%")
        insertSensor("sensor.robika_brush_1_time", name: "Brush Left Time", state: "296", unit: "h")
        insertSensor("sensor.robika_brush_2_time", name: "Brush Left Time", state: "196", unit: "h")

        let pairs = makeViewModel().rows.map { "\($0.value)/\($0.timeLeft ?? "-")" }.sorted()
        #expect(pairs == ["80%/196 h", "99%/296 h"])
    }

    /// A paired row shows its stem, so it must sort by the stem, not the sensor's full name.
    @Test func rows_sortedByTheNameShownAfterPairing() {
        insertSensor("sensor.robika_filter_level", name: "Filter Life Level", state: "98", unit: "%")
        insertSensor("sensor.robika_filter_time", name: "Filter Left Time", state: "146", unit: "h")
        insertSensor("sensor.robika_filter_cleaner", name: "Filter Cleaner", state: "ok")

        #expect(makeViewModel().rows.map(\.name) == ["Filter", "Filter Cleaner"])
    }

    @Test func rows_unpairedReadingsStayOnTheirOwn() {
        insertSensor("sensor.robika_filter_level", name: "Filter Life Level", state: "98", unit: "%")
        insertSensor("sensor.robika_mop_time", name: "Mop Left Time", state: "78", unit: "h")

        let rows = makeViewModel().rows
        #expect(rows.map(\.name) == ["Filter Life Level", "Mop Left Time"])
        #expect(rows.allSatisfy { $0.timeLeft == nil })
    }

    /// "Unknown left" says nothing; a time without a number stays its own row instead.
    @Test func rows_timeWithoutANumber_isNotPaired() {
        insertSensor("sensor.robika_det_level", name: "Detergent Left Level", state: "40", unit: "%")
        insertSensor("sensor.robika_det_time", name: "Detergent Left Time", state: "unknown", unit: "h")

        #expect(makeViewModel().rows.count == 2)
    }

    // MARK: - Helpers

    private func makeViewModel(locale: Locale = Locale(identifier: "en_US")) -> DeviceSensorsViewModel {
        DeviceSensorsViewModel(deviceId: "robika", context: context, locale: locale)
    }

    @discardableResult
    private func insertSensor(
        _ id: String, name: String, state: String, unit: String? = nil, deviceId: String = "robika"
    ) -> SensorEntity {
        let sensor = SensorEntity(entityId: id, name: name, state: state, unitOfMeasurement: unit)
        sensor.deviceId = deviceId
        context.insert(sensor)
        return sensor
    }

    @discardableResult
    private func insertBinarySensor(
        _ id: String, name: String, deviceClass: BinarySensorEntity.DeviceClass
    ) -> BinarySensorEntity {
        let binarySensor = BinarySensorEntity(entityId: id, name: name, state: .on, deviceClass: deviceClass)
        binarySensor.deviceId = "robika"
        context.insert(binarySensor)
        return binarySensor
    }
}
