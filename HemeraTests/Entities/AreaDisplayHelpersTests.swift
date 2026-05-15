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
            LightEntity.self, CoverEntity.self, SceneEntity.self, SensorEntity.self,
            SwitchEntity.self, ButtonEntity.self, AutomationEntity.self,
            BinarySensorEntity.self, ClimateEntity.self, AreaEntity.self, HomeTile.self
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

        #expect(t == "21°C")
        #expect(h == "47%")
    }

    @Test
    func climateSummary_roundsFractionalValues() {
        let temp = SensorEntity(entityId: "sensor.temp", name: "T", state: "21.6", deviceClass: "temperature", unitOfMeasurement: "°C")

        let (t, _) = AreaDisplayHelpers.climateSummary(from: [temp])

        #expect(t == "22°C")
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

    // MARK: - statusIcons

    @Test
    func statusIcons_lightsOff_addsInactiveLightIcon() {
        let area = AreaEntity(areaId: "a", name: "A")
        let light = LightEntity(entityId: "light.a", name: "A", state: .off)
        light.area = area
        context.insert(area); context.insert(light)

        let icons = AreaDisplayHelpers.statusIcons(from: area)

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

        let icons = AreaDisplayHelpers.statusIcons(from: area)

        #expect(icons.first(where: { $0.category == .light })?.isActive == true)
    }

    @Test
    func statusIcons_areaWithoutCovers_omitsCoverIcon() {
        let area = AreaEntity(areaId: "a", name: "A")
        let light = LightEntity(entityId: "light.a", name: "A", state: .off)
        light.area = area
        context.insert(area); context.insert(light)

        let icons = AreaDisplayHelpers.statusIcons(from: area)

        #expect(icons.contains(where: { $0.category == .cover }) == false)
    }

    @Test
    func statusIcons_motionSensorOn_marksBinarySensorActive() {
        let area = AreaEntity(areaId: "a", name: "A")
        let motion = BinarySensorEntity(entityId: "binary_sensor.motion", name: "Motion", state: .on, deviceClass: .motion)
        motion.area = area
        context.insert(area); context.insert(motion)

        let icons = AreaDisplayHelpers.statusIcons(from: area)

        #expect(icons.first(where: { $0.category == .binarySensor })?.isActive == true)
    }

    @Test
    func statusIcons_irrelevantBinarySensors_areIgnored() {
        let area = AreaEntity(areaId: "a", name: "A")
        // No deviceClass in [.motion, .door, .window] → should not produce an icon.
        let smoke = BinarySensorEntity(entityId: "binary_sensor.smoke", name: "Smoke", state: .on, deviceClass: .smoke)
        smoke.area = area
        context.insert(area); context.insert(smoke)

        let icons = AreaDisplayHelpers.statusIcons(from: area)

        #expect(icons.contains(where: { $0.category == .binarySensor }) == false)
    }

    @Test
    func statusIcons_unavailableLightIsNotCountedAsOn() {
        let area = AreaEntity(areaId: "a", name: "A")
        let light = LightEntity(entityId: "light.a", name: "A", state: .on)
        light.isAvailable = false
        light.area = area
        context.insert(area); context.insert(light)

        let icons = AreaDisplayHelpers.statusIcons(from: area)

        #expect(icons.first(where: { $0.category == .light })?.isActive == false)
    }
}
