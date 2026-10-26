import Foundation
import SwiftData
import Testing
@testable import Hemera

@MainActor
struct AreaDisplayHelpersTests {

    let container: ModelContainer
    let context: ModelContext

    init() {
        let schema = Schema([
            LightEntity.self, CoverEntity.self, SceneEntity.self, ScriptEntity.self, SensorEntity.self,
            SwitchEntity.self, ButtonEntity.self, AutomationEntity.self,
            BinarySensorEntity.self, ClimateEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    // MARK: - climateSummary

    @Test
    func climateSummary_withTemperatureAndHumidity_returnsBoth() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "T", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C")
        let humidity = SensorEntity(entityId: "sensor.hum", name: "H", state: "47", deviceClass: "humidity", unitOfMeasurement: "%")

        let (t, h) = AreaDisplayHelpers.climateSummary(from: [temp, humidity])

        // Whole values still render with one decimal, using the current locale's separator.
        #expect(t == 21.0.formatted(.number.precision(.fractionLength(1))) + "°C")
        #expect(h == 47.0.formatted(.number.precision(.fractionLength(1))) + "%")
    }

    @Test
    func climateSummary_formatsFractionalValuesToOneDecimal() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "T", state: "21.6", deviceClass: "temperature", unitOfMeasurement: "°C")

        let (t, _) = AreaDisplayHelpers.climateSummary(from: [temp])

        // Fractional value is preserved to one decimal, not rounded to a whole number.
        #expect(t == 21.6.formatted(.number.precision(.fractionLength(1))) + "°C")
    }

    @Test
    func climateSummary_roundsToOneDecimal() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "T", state: "21.68", deviceClass: "temperature", unitOfMeasurement: "°C")

        let (t, _) = AreaDisplayHelpers.climateSummary(from: [temp])

        // More than one decimal is rounded, not truncated.
        #expect(t == 21.7.formatted(.number.precision(.fractionLength(1))) + "°C")
    }

    @Test
    func climateSummary_withNonNumericState_returnsNil() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "T", state: "unavailable", deviceClass: "temperature", unitOfMeasurement: "°C")

        let (t, _) = AreaDisplayHelpers.climateSummary(from: [temp])

        #expect(t == nil)
    }

    @Test
    func climateSummary_withOnlyIrrelevantSensors_returnsNil() {
        let illuminance = SensorEntity(entityId: "sensor.lux", name: "Lux", state: "100", deviceClass: "illuminance", unitOfMeasurement: "lx")

        let (t, h) = AreaDisplayHelpers.climateSummary(from: [illuminance])

        #expect(t == nil)
        #expect(h == nil)
    }

    // MARK: - representativeSensors

    @Test
    func representativeSensors_withMixedSensors_returnsFirstVisibleOfEachClass() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C")
        let laterTemp = SensorEntity(entityId: "sensor.temp.later", name: "Late", state: "30", deviceClass: "temperature", unitOfMeasurement: "°C")
        let hum = SensorEntity(entityId: "sensor.humidity", name: "Hum", state: "47", deviceClass: "humidity", unitOfMeasurement: "%")

        let (temperature, humidity) = AreaDisplayHelpers.representativeSensors(from: [temp, hum, laterTemp])

        #expect(temperature?.entityId == "sensor.temp")
        #expect(humidity?.entityId == "sensor.humidity")
    }

    @Test
    func representativeSensors_withHiddenSensorFirst_skipsItForLaterVisible() {
        let hidden = SensorEntity(entityId: "sensor.temp.hidden", name: "Hidden", state: "18", deviceClass: "temperature", unitOfMeasurement: "°C")
        hidden.isHiddenInHA = true
        let visible = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C")

        let (temperature, _) = AreaDisplayHelpers.representativeSensors(from: [hidden, visible])

        #expect(temperature?.entityId == "sensor.temp")
    }

    @Test
    func representativeSensors_withNoMatchingSensor_returnsNilForBoth() {
        let illuminance = SensorEntity(entityId: "sensor.lux", name: "Lux", state: "100", deviceClass: "illuminance", unitOfMeasurement: "lx")

        let (temperature, humidity) = AreaDisplayHelpers.representativeSensors(from: [illuminance])

        #expect(temperature == nil)
        #expect(humidity == nil)
    }

    // MARK: - climateLabel

    @Test
    func climateLabel_withTemperatureAndHumidity_joinsWithBulletSeparator() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C")
        let humidity = SensorEntity(entityId: "sensor.humidity", name: "Hum", state: "47", deviceClass: "humidity", unitOfMeasurement: "%")

        let label = AreaDisplayHelpers.climateLabel(from: [temp, humidity])

        let expected = 21.0.formatted(.number.precision(.fractionLength(1))) + "°C · "
            + 47.0.formatted(.number.precision(.fractionLength(1))) + "%"
        #expect(label == expected)
    }

    @Test
    func climateLabel_withOnlyTemperature_returnsJustTemperature() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C")

        let label = AreaDisplayHelpers.climateLabel(from: [temp])

        #expect(label == 21.0.formatted(.number.precision(.fractionLength(1))) + "°C")
    }

    @Test
    func climateLabel_withOnlyHumidity_returnsJustHumidity() {
        let humidity = SensorEntity(entityId: "sensor.humidity", name: "Hum", state: "47", deviceClass: "humidity", unitOfMeasurement: "%")

        let label = AreaDisplayHelpers.climateLabel(from: [humidity])

        #expect(label == 47.0.formatted(.number.precision(.fractionLength(1))) + "%")
    }

    @Test
    func climateLabel_withUnreadableTemperature_omitsItWithoutPlaceholder() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "unavailable", deviceClass: "temperature", unitOfMeasurement: "°C")
        let humidity = SensorEntity(entityId: "sensor.humidity", name: "Hum", state: "47", deviceClass: "humidity", unitOfMeasurement: "%")

        let label = AreaDisplayHelpers.climateLabel(from: [temp, humidity])

        #expect(label == 47.0.formatted(.number.precision(.fractionLength(1))) + "%")
    }

    @Test
    func climateLabel_withNoClimateSensor_returnsNil() {
        let illuminance = SensorEntity(entityId: "sensor.lux", name: "Lux", state: "100", deviceClass: "illuminance", unitOfMeasurement: "lx")

        let label = AreaDisplayHelpers.climateLabel(from: [illuminance])

        #expect(label == nil)
    }

    // MARK: - statusIcons

    @Test
    func statusIcons_lightsOff_addsInactiveLightIcon() {
        let area = AreaEntity(areaId: "a", name: "A")
        let light = LightEntity(entityId: "light.a", name: "A", state: .off)
        light.area = area
        context.insert(area); context.insert(light)

        let icons = AreaDisplayHelpers.statusIcons(from: area, iconResolver: IconTranslationsFixture.resolver())

        #expect(icons.count == 1)
        #expect(icons[0].category == .light)
        #expect(icons[0].isActive == false)
    }

    @Test
    func statusIcons_anyLightOn_marksLightActive() {
        let area = AreaEntity(areaId: "a", name: "A")
        let off = LightEntity(entityId: "light.off", name: "Off", state: .off)
        let on = LightEntity(entityId: "light.on", name: "On", state: .on)
        off.area = area
        on.area = area
        context.insert(area); context.insert(off); context.insert(on)

        let icons = AreaDisplayHelpers.statusIcons(from: area, iconResolver: IconTranslationsFixture.resolver())

        #expect(icons.first(where: { $0.category == .light })?.isActive == true)
    }

    @Test
    func statusIcons_areaWithoutCovers_omitsCoverIcon() {
        let area = AreaEntity(areaId: "a", name: "A")
        let light = LightEntity(entityId: "light.a", name: "A", state: .off)
        light.area = area
        context.insert(area); context.insert(light)

        let icons = AreaDisplayHelpers.statusIcons(from: area, iconResolver: IconTranslationsFixture.resolver())

        #expect(icons.contains(where: { $0.category == .cover }) == false)
    }

    @Test
    func statusIcons_motionSensorOn_marksBinarySensorActive() {
        let area = AreaEntity(areaId: "a", name: "A")
        let motion = BinarySensorEntity(entityId: "binary_sensor.motion", name: "Motion", state: .on, deviceClass: .motion)
        motion.area = area
        context.insert(area); context.insert(motion)

        let icons = AreaDisplayHelpers.statusIcons(from: area, iconResolver: IconTranslationsFixture.resolver())

        #expect(icons.first(where: { $0.category == .binarySensor })?.isActive == true)
    }

    @Test
    func statusIcons_irrelevantBinarySensors_areIgnored() {
        let area = AreaEntity(areaId: "a", name: "A")
        // No deviceClass in [.motion, .door, .window] → should not produce an icon.
        let smoke = BinarySensorEntity(entityId: "binary_sensor.smoke", name: "Smoke", state: .on, deviceClass: .smoke)
        smoke.area = area
        context.insert(area); context.insert(smoke)

        let icons = AreaDisplayHelpers.statusIcons(from: area, iconResolver: IconTranslationsFixture.resolver())

        #expect(icons.contains(where: { $0.category == .binarySensor }) == false)
    }

    @Test
    func statusIcons_unavailableLightIsNotCountedAsOn() {
        let area = AreaEntity(areaId: "a", name: "A")
        let light = LightEntity(entityId: "light.a", name: "A", state: .on)
        light.isAvailable = false
        light.area = area
        context.insert(area); context.insert(light)

        let icons = AreaDisplayHelpers.statusIcons(from: area, iconResolver: IconTranslationsFixture.resolver())

        #expect(icons.first(where: { $0.category == .light })?.isActive == false)
    }
}
