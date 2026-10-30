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
        let temp = SensorEntity(entityId: "sensor.temp", name: "T", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let humidity = SensorEntity(entityId: "sensor.hum", name: "H", state: "47", deviceClass: "humidity", unitOfMeasurement: "%", stateClass: "measurement")
        let area = makeArea([temp, humidity])

        let (t, h) = AreaDisplayHelpers.climateSummary(for: area)

        // Whole values still render with one decimal, using the current locale's separator.
        #expect(t == 21.0.formatted(.number.precision(.fractionLength(1))) + "°C")
        #expect(h == 47.0.formatted(.number.precision(.fractionLength(1))) + "%")
    }

    @Test
    func climateSummary_formatsFractionalValuesToOneDecimal() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "T", state: "21.6", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let area = makeArea([temp])

        let (t, _) = AreaDisplayHelpers.climateSummary(for: area)

        // Fractional value is preserved to one decimal, not rounded to a whole number.
        #expect(t == 21.6.formatted(.number.precision(.fractionLength(1))) + "°C")
    }

    @Test
    func climateSummary_roundsToOneDecimal() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "T", state: "21.68", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let area = makeArea([temp])

        let (t, _) = AreaDisplayHelpers.climateSummary(for: area)

        // More than one decimal is rounded, not truncated.
        #expect(t == 21.7.formatted(.number.precision(.fractionLength(1))) + "°C")
    }

    @Test
    func climateSummary_withNonNumericState_returnsNil() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "T", state: "unavailable", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let area = makeArea([temp])

        let (t, _) = AreaDisplayHelpers.climateSummary(for: area)

        #expect(t == nil)
    }

    @Test
    func climateSummary_withOnlyIrrelevantSensors_returnsNil() {
        let illuminance = SensorEntity(entityId: "sensor.lux", name: "Lux", state: "100", deviceClass: "illuminance", unitOfMeasurement: "lx")
        let area = makeArea([illuminance])

        let (t, h) = AreaDisplayHelpers.climateSummary(for: area)

        #expect(t == nil)
        #expect(h == nil)
    }

    // MARK: - representativeSensors

    @Test
    func representativeSensors_withMixedSensors_returnsLowestEntityIdOfEachClass() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let laterTemp = SensorEntity(entityId: "sensor.temp.later", name: "Late", state: "30", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let hum = SensorEntity(entityId: "sensor.humidity", name: "Hum", state: "47", deviceClass: "humidity", unitOfMeasurement: "%", stateClass: "measurement")
        let area = makeArea([temp, hum, laterTemp])

        let (temperature, humidity) = AreaDisplayHelpers.representativeSensors(for: area)

        #expect(temperature?.entityId == "sensor.temp")
        #expect(humidity?.entityId == "sensor.humidity")
    }

    @Test
    func representativeSensors_withHiddenSensorFirst_skipsItForLaterVisible() {
        let hidden = SensorEntity(entityId: "sensor.temp.hidden", name: "Hidden", state: "18", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        hidden.isHiddenInHA = true
        let visible = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let area = makeArea([hidden, visible])

        let (temperature, _) = AreaDisplayHelpers.representativeSensors(for: area)

        #expect(temperature?.entityId == "sensor.temp")
    }

    @Test
    func representativeSensors_withNoMatchingSensor_returnsNilForBoth() {
        let illuminance = SensorEntity(entityId: "sensor.lux", name: "Lux", state: "100", deviceClass: "illuminance", unitOfMeasurement: "lx")
        let area = makeArea([illuminance])

        let (temperature, humidity) = AreaDisplayHelpers.representativeSensors(for: area)

        #expect(temperature == nil)
        #expect(humidity == nil)
    }

    @Test
    func representativeSensors_withTemperatureAssignment_returnsAssignedEvenOverBetterGuess() {
        let assigned = SensorEntity(entityId: "sensor.assigned", name: "Assigned", state: "19", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: nil)
        let guess = SensorEntity(entityId: "sensor.a.temperature", name: "Guess", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let area = makeArea([guess, assigned])
        area.temperatureEntityId = "sensor.assigned"

        let (temperature, _) = AreaDisplayHelpers.representativeSensors(for: area)

        #expect(temperature?.entityId == "sensor.assigned")
    }

    @Test
    func representativeSensors_withHumidityAssignment_returnsAssignedEvenOverBetterGuess() {
        let assigned = SensorEntity(entityId: "sensor.assigned", name: "Assigned", state: "60", deviceClass: "humidity", unitOfMeasurement: "%", stateClass: nil)
        let guess = SensorEntity(entityId: "sensor.a.humidity", name: "Guess", state: "47", deviceClass: "humidity", unitOfMeasurement: "%", stateClass: "measurement")
        let area = makeArea([guess, assigned])
        area.humidityEntityId = "sensor.assigned"

        let (_, humidity) = AreaDisplayHelpers.representativeSensors(for: area)

        #expect(humidity?.entityId == "sensor.assigned")
    }

    @Test
    func representativeSensors_withAssignmentToUnknownEntityId_fallsBackToGuess() {
        let guess = SensorEntity(entityId: "sensor.a.temperature", name: "Guess", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let area = makeArea([guess])
        area.temperatureEntityId = "sensor.not.in.area"

        let (temperature, _) = AreaDisplayHelpers.representativeSensors(for: area)

        #expect(temperature?.entityId == "sensor.a.temperature")
    }

    @Test
    func representativeSensors_withAssignedSensorHidden_stillReturnsIt() {
        let assigned = SensorEntity(entityId: "sensor.assigned", name: "Assigned", state: "19", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: nil)
        assigned.isHiddenInHA = true
        let guess = SensorEntity(entityId: "sensor.a.temperature", name: "Guess", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let area = makeArea([guess, assigned])
        area.temperatureEntityId = "sensor.assigned"

        let (temperature, _) = AreaDisplayHelpers.representativeSensors(for: area)

        #expect(temperature?.entityId == "sensor.assigned")
    }

    @Test
    func representativeSensors_noAssignment_setpointWithNilStateClass_neverChosen() {
        // The guest-bathroom bug: a setpoint without `state_class` must never be chosen.
        let setpoint = SensorEntity(entityId: "sensor.a.setpoint", name: "Setpoint", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C")
        let area = makeArea([setpoint])

        let (temperature, humidity) = AreaDisplayHelpers.representativeSensors(for: area)

        #expect(temperature == nil)
        #expect(humidity == nil)
    }

    @Test
    func representativeSensors_twoValidSensors_returnsLowestEntityIdRegardlessOfArrayOrder() {
        func pair() -> (SensorEntity, SensorEntity) {
            (
                SensorEntity(entityId: "sensor.a.temperature", name: "A", state: "20", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement"),
                SensorEntity(entityId: "sensor.b.temperature", name: "B", state: "22", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
            )
        }

        // Each area needs its own instances: assigning `.area` moves a sensor rather than sharing it.
        let (lower, higher) = pair()
        let forward = makeArea([lower, higher])
        let (lowerAgain, higherAgain) = pair()
        let reversed = makeArea([higherAgain, lowerAgain])

        let (forwardTemp, _) = AreaDisplayHelpers.representativeSensors(for: forward)
        let (reversedTemp, _) = AreaDisplayHelpers.representativeSensors(for: reversed)

        #expect(forwardTemp?.entityId == "sensor.a.temperature")
        #expect(reversedTemp?.entityId == "sensor.a.temperature")
    }

    @Test
    func representativeSensors_onlySetpointNoMeasurement_returnsNilNotSetpoint() {
        let setpoint = SensorEntity(entityId: "sensor.guest_bathroom_target", name: "Target", state: "21.5", deviceClass: "temperature", unitOfMeasurement: "°C")
        let lux = SensorEntity(entityId: "sensor.lux", name: "Lux", state: "100", deviceClass: "illuminance", unitOfMeasurement: "lx")
        let area = makeArea([setpoint, lux])

        let (temperature, humidity) = AreaDisplayHelpers.representativeSensors(for: area)

        #expect(temperature == nil)
        #expect(humidity == nil)
    }

    // MARK: - climateLabel

    @Test
    func climateLabel_withTemperatureAndHumidity_joinsWithBulletSeparator() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let humidity = SensorEntity(entityId: "sensor.humidity", name: "Hum", state: "47", deviceClass: "humidity", unitOfMeasurement: "%", stateClass: "measurement")
        let area = makeArea([temp, humidity])

        let label = AreaDisplayHelpers.climateLabel(for: area)

        let expected = 21.0.formatted(.number.precision(.fractionLength(1))) + "°C · "
            + 47.0.formatted(.number.precision(.fractionLength(1))) + "%"
        #expect(label == expected)
    }

    @Test
    func climateLabel_withOnlyTemperature_returnsJustTemperature() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "21", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let area = makeArea([temp])

        let label = AreaDisplayHelpers.climateLabel(for: area)

        #expect(label == 21.0.formatted(.number.precision(.fractionLength(1))) + "°C")
    }

    @Test
    func climateLabel_withOnlyHumidity_returnsJustHumidity() {
        let humidity = SensorEntity(entityId: "sensor.humidity", name: "Hum", state: "47", deviceClass: "humidity", unitOfMeasurement: "%", stateClass: "measurement")
        let area = makeArea([humidity])

        let label = AreaDisplayHelpers.climateLabel(for: area)

        #expect(label == 47.0.formatted(.number.precision(.fractionLength(1))) + "%")
    }

    @Test
    func climateLabel_withUnreadableTemperature_omitsItWithoutPlaceholder() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "Temp", state: "unavailable", deviceClass: "temperature", unitOfMeasurement: "°C", stateClass: "measurement")
        let humidity = SensorEntity(entityId: "sensor.humidity", name: "Hum", state: "47", deviceClass: "humidity", unitOfMeasurement: "%", stateClass: "measurement")
        let area = makeArea([temp, humidity])

        let label = AreaDisplayHelpers.climateLabel(for: area)

        #expect(label == 47.0.formatted(.number.precision(.fractionLength(1))) + "%")
    }

    @Test
    func climateLabel_withNoClimateSensor_returnsNil() {
        let illuminance = SensorEntity(entityId: "sensor.lux", name: "Lux", state: "100", deviceClass: "illuminance", unitOfMeasurement: "lx")
        let area = makeArea([illuminance])

        let label = AreaDisplayHelpers.climateLabel(for: area)

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

    private func makeArea(_ sensors: [SensorEntity]) -> AreaEntity {
        let area = AreaEntity(areaId: "area-\(UUID().uuidString)", name: "Test Area")
        for sensor in sensors {
            sensor.area = area
            context.insert(sensor)
        }
        context.insert(area)
        return area
    }
}
