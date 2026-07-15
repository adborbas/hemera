import Foundation
import SwiftData
import TileGridEngine

/// Seeds the SwiftData store with realistic sample entities for demo mode.
enum DemoDataProvider {

    static func seedDemoData(into context: ModelContext) {
        let livingRoom = AreaEntity(areaId: "living_room", name: "Living Room", icon: "mdi:sofa", sortOrder: 0)
        let bedroom = AreaEntity(areaId: "bedroom", name: "Bedroom", icon: "mdi:bed", sortOrder: 1)
        let kitchen = AreaEntity(areaId: "kitchen", name: "Kitchen", icon: "mdi:silverware-fork-knife", sortOrder: 2)
        let bathroom = AreaEntity(areaId: "bathroom", name: "Bathroom", icon: "mdi:shower", sortOrder: 3)
        let office = AreaEntity(areaId: "office", name: "Office", icon: "mdi:desk", sortOrder: 4)
        let garden = AreaEntity(areaId: "garden", name: "Garden", icon: "mdi:flower", sortOrder: 5)

        context.insert(livingRoom)
        context.insert(bedroom)
        context.insert(kitchen)
        context.insert(bathroom)
        context.insert(office)
        context.insert(garden)

        // MARK: - Floors

        let groundFloor = FloorEntity(floorId: "ground", name: "Ground Floor", level: 0, sortOrder: 0)
        let upstairs = FloorEntity(floorId: "upstairs", name: "Upstairs", level: 1, sortOrder: 1)
        context.insert(groundFloor)
        context.insert(upstairs)

        livingRoom.floor = groundFloor
        kitchen.floor = groundFloor
        bathroom.floor = groundFloor
        bedroom.floor = upstairs
        office.floor = upstairs
        // garden is intentionally left floorless — it appears in the "Other" section.

        // MARK: - Living Room

        let ceilingLight = LightEntity(
            entityId: "light.living_room_ceiling",
            name: "Ceiling Light",
            state: .on,
            brightness: 204, // ~80%
            colorMode: "color_temp",
            colorTemp: 350,
            minMireds: 153,
            maxMireds: 500,
            supportedColorModes: ["brightness", "color_temp"],
            supportedFeaturesRaw: 0
        )

        let floorLamp = LightEntity(
            entityId: "light.living_room_floor_lamp",
            name: "Floor Lamp",
            state: .off,
            supportedColorModes: ["brightness"],
            supportedFeaturesRaw: 0
        )

        let tvBacklight = LightEntity(
            entityId: "light.living_room_tv_backlight",
            name: "TV Backlight",
            state: .on,
            brightness: 128, // ~50%
            colorMode: "hs",
            hsColor: [240.0, 80.0],
            minMireds: 153,
            maxMireds: 500,
            supportedColorModes: ["brightness", "color_temp", "hs"],
            supportedFeaturesRaw: 0
        )

        let blinds = CoverEntity(
            entityId: "cover.living_room_blinds",
            name: "Blinds",
            state: .open,
            currentPosition: 70,
            supportedFeaturesRaw: CoverEntity.Features.allDemo.rawValue,
            deviceClass: .blind
        )

        let curtains = CoverEntity(
            entityId: "cover.living_room_curtains",
            name: "Curtains",
            state: .open,
            currentPosition: 100,
            supportedFeaturesRaw: CoverEntity.Features.allDemo.rawValue,
            deviceClass: .curtain
        )

        let movieScene = SceneEntity(entityId: "scene.movie_night", name: "Movie Night")
        let relaxScene = SceneEntity(entityId: "scene.relax", name: "Relax")

        let motionLights = AutomationEntity(
            entityId: "automation.motion_lights",
            name: "Motion Lights",
            state: .on,
            lastTriggered: Date().addingTimeInterval(-300),
            icon: "mdi:lightbulb"
        )

        let livingMotion = BinarySensorEntity(
            entityId: "binary_sensor.living_room_motion",
            name: "Motion",
            state: .on,
            deviceClass: .motion
        )

        let livingTemp = SensorEntity(
            entityId: "sensor.living_room_temperature",
            name: "Living Room Temperature",
            state: "22",
            deviceClass: "temperature",
            unitOfMeasurement: "°C"
        )

        let livingHumidity = SensorEntity(
            entityId: "sensor.living_room_humidity",
            name: "Living Room Humidity",
            state: "45",
            deviceClass: "humidity",
            unitOfMeasurement: "%"
        )

        let livingRoomAC = ClimateEntity(
            entityId: "climate.living_room_ac",
            name: "AC",
            state: .cool,
            hvacAction: .cooling,
            currentTemperature: 24.5,
            temperature: 22,
            minTemp: 16, maxTemp: 30,
            hvacModesRaw: ["off", "cool", "heat", "heat_cool", "auto", "dry", "fan_only"],
            fanMode: "auto",
            fanModesRaw: ["auto", "low", "medium", "high"],
            swingMode: "off",
            swingModesRaw: ["off", "vertical", "horizontal", "both"],
            presetMode: "comfort",
            presetModesRaw: ["eco", "comfort", "boost"],
            supportedFeaturesRaw: 1 | 2 | 8 | 16 | 32 | 128 | 256
        )

        // MARK: - Bedroom

        let bedsideLamp = LightEntity(
            entityId: "light.bedroom_bedside_lamp",
            name: "Bedside Lamp",
            state: .off,
            supportedColorModes: ["brightness"],
            supportedFeaturesRaw: 0
        )

        let readingLight = LightEntity(
            entityId: "light.bedroom_reading",
            name: "Reading Light",
            state: .on,
            brightness: 102, // ~40%
            supportedColorModes: ["brightness"],
            supportedFeaturesRaw: 0
        )

        let blackoutBlinds = CoverEntity(
            entityId: "cover.bedroom_blackout",
            name: "Blackout Blinds",
            state: .closed,
            currentPosition: 0,
            supportedFeaturesRaw: CoverEntity.Features.allDemo.rawValue,
            deviceClass: .blind
        )

        let bedroomDoor = BinarySensorEntity(
            entityId: "binary_sensor.bedroom_door",
            name: "Door",
            state: .off,
            deviceClass: .door
        )

        let nightMode = AutomationEntity(
            entityId: "automation.night_mode",
            name: "Night Mode",
            state: .off,
            icon: "mdi:nonexistent-icon-xyz"
        )

        let goodnightScene = SceneEntity(entityId: "scene.goodnight", name: "Goodnight")
        let morningScene = SceneEntity(entityId: "scene.morning", name: "Good Morning")

        let bedroomHeater = ClimateEntity(
            entityId: "climate.bedroom_heater",
            name: "Heater",
            state: .heat,
            hvacAction: .heating,
            currentTemperature: 19.8,
            temperature: 21,
            minTemp: 5, maxTemp: 30,
            hvacModesRaw: ["off", "heat"],
            supportedFeaturesRaw: 1 | 128 | 256
        )

        let bedroomTemp = SensorEntity(
            entityId: "sensor.bedroom_temperature",
            name: "Bedroom Temperature",
            state: "20",
            deviceClass: "temperature",
            unitOfMeasurement: "°C"
        )

        let bedroomHumidity = SensorEntity(
            entityId: "sensor.bedroom_humidity",
            name: "Bedroom Humidity",
            state: "52",
            deviceClass: "humidity",
            unitOfMeasurement: "%"
        )

        // MARK: - Kitchen

        let kitchenLights = LightEntity(
            entityId: "light.kitchen_lights",
            name: "Kitchen Lights",
            state: .on,
            brightness: 255, // 100%
            supportedColorModes: ["brightness"],
            supportedFeaturesRaw: 0
        )

        let counterLights = LightEntity(
            entityId: "light.kitchen_counter",
            name: "Counter Lights",
            state: .on,
            brightness: 180, // ~70%
            supportedColorModes: ["brightness"],
            supportedFeaturesRaw: 0
        )

        let rollerShutter = CoverEntity(
            entityId: "cover.kitchen_roller_shutter",
            name: "Roller Shutter",
            state: .open,
            currentPosition: 100,
            supportedFeaturesRaw: CoverEntity.Features.allDemo.rawValue,
            deviceClass: .shutter
        )

        let kitchenSmoke = BinarySensorEntity(
            entityId: "binary_sensor.kitchen_smoke",
            name: "Smoke Detector",
            state: .off,
            deviceClass: .smoke
        )

        let coffeeMachine = SwitchEntity(
            entityId: "switch.kitchen_coffee_machine",
            name: "Coffee Machine",
            state: .off,
            deviceClass: .outlet
        )

        let cookingScene = SceneEntity(entityId: "scene.cooking", name: "Cooking")

        let kitchenTemp = SensorEntity(
            entityId: "sensor.kitchen_temperature",
            name: "Kitchen Temperature",
            state: "24",
            deviceClass: "temperature",
            unitOfMeasurement: "°C"
        )

        let kitchenHumidity = SensorEntity(
            entityId: "sensor.kitchen_humidity",
            name: "Kitchen Humidity",
            state: "58",
            deviceClass: "humidity",
            unitOfMeasurement: "%"
        )

        // MARK: - Bathroom

        let bathroomLight = LightEntity(
            entityId: "light.bathroom_ceiling",
            name: "Ceiling Light",
            state: .off,
            supportedColorModes: ["brightness"],
            supportedFeaturesRaw: 0
        )

        let mirrorLight = LightEntity(
            entityId: "light.bathroom_mirror",
            name: "Mirror Light",
            state: .on,
            brightness: 230, // ~90%
            supportedColorModes: ["brightness"],
            supportedFeaturesRaw: 0
        )

        let bathroomWindow = CoverEntity(
            entityId: "cover.bathroom_window",
            name: "Window Shade",
            state: .closed,
            currentPosition: 0,
            supportedFeaturesRaw: CoverEntity.Features.allDemo.rawValue,
            deviceClass: .shade
        )

        let bathroomTemp = SensorEntity(
            entityId: "sensor.bathroom_temperature",
            name: "Bathroom Temperature",
            state: "25",
            deviceClass: "temperature",
            unitOfMeasurement: "°C"
        )

        let bathroomHumidity = SensorEntity(
            entityId: "sensor.bathroom_humidity",
            name: "Bathroom Humidity",
            state: "72",
            deviceClass: "humidity",
            unitOfMeasurement: "%"
        )

        // MARK: - Office

        let deskLamp = LightEntity(
            entityId: "light.office_desk",
            name: "Desk Lamp",
            state: .on,
            brightness: 255, // 100%
            colorMode: "color_temp",
            colorTemp: 280,
            minMireds: 153,
            maxMireds: 500,
            supportedColorModes: ["brightness", "color_temp", "hs"],
            supportedFeaturesRaw: 0
        )

        let officeOverhead = LightEntity(
            entityId: "light.office_overhead",
            name: "Overhead Light",
            state: .off,
            supportedColorModes: ["brightness"],
            supportedFeaturesRaw: 0
        )

        let officeBlinds = CoverEntity(
            entityId: "cover.office_blinds",
            name: "Blinds",
            state: .open,
            currentPosition: 40,
            supportedFeaturesRaw: CoverEntity.Features.allDemo.rawValue,
            deviceClass: .blind
        )

        let officeOccupancy = BinarySensorEntity(
            entityId: "binary_sensor.office_occupancy",
            name: "Occupancy",
            state: .on,
            deviceClass: .occupancy
        )

        let deskFan = SwitchEntity(
            entityId: "switch.office_fan",
            name: "Fan",
            state: .on,
            deviceClass: .switch,
            icon: "mdi:fan"
        )

        let focusScene = SceneEntity(entityId: "scene.focus", name: "Focus", icon: "mdi:timer")

        let restartRouter = ButtonEntity(
            entityId: "button.restart_router",
            name: "Restart Router",
            deviceClass: .restart,
            icon: "mdi:wifi"
        )

        let officeTemp = SensorEntity(
            entityId: "sensor.office_temperature",
            name: "Office Temperature",
            state: "21",
            deviceClass: "temperature",
            unitOfMeasurement: "°C"
        )

        let officeHumidity = SensorEntity(
            entityId: "sensor.office_humidity",
            name: "Office Humidity",
            state: "40",
            deviceClass: "humidity",
            unitOfMeasurement: "%"
        )

        // MARK: - Garden (sensor-only area)

        let gardenTemp = SensorEntity(
            entityId: "sensor.garden_temperature",
            name: "Garden Temperature",
            state: "18",
            deviceClass: "temperature",
            unitOfMeasurement: "°C"
        )

        let gardenHumidity = SensorEntity(
            entityId: "sensor.garden_humidity",
            name: "Garden Humidity",
            state: "65",
            deviceClass: "humidity",
            unitOfMeasurement: "%"
        )

        // Insert all entities into context FIRST
        let allEntities: [any PersistentModel] = [
            // Living Room
            ceilingLight, floorLamp, tvBacklight, blinds, curtains,
            movieScene, relaxScene, motionLights, livingMotion, livingTemp, livingHumidity,
            livingRoomAC,
            // Bedroom
            bedsideLamp, readingLight, blackoutBlinds,
            bedroomDoor, nightMode, goodnightScene, morningScene, bedroomTemp, bedroomHumidity,
            bedroomHeater,
            // Kitchen
            kitchenLights, counterLights, rollerShutter,
            kitchenSmoke, coffeeMachine, cookingScene, kitchenTemp, kitchenHumidity,
            // Bathroom
            bathroomLight, mirrorLight, bathroomWindow,
            bathroomTemp, bathroomHumidity,
            // Office
            deskLamp, officeOverhead, officeBlinds,
            officeOccupancy, deskFan, focusScene, restartRouter, officeTemp, officeHumidity,
            // Garden
            gardenTemp, gardenHumidity
        ]
        for entity in allEntities {
            context.insert(entity)
        }

        // THEN set area relationships (both objects in context → inverse is maintained)
        ceilingLight.area = livingRoom
        floorLamp.area = livingRoom
        tvBacklight.area = livingRoom
        blinds.area = livingRoom
        curtains.area = livingRoom
        movieScene.area = livingRoom
        relaxScene.area = livingRoom
        motionLights.area = livingRoom
        livingMotion.area = livingRoom
        livingTemp.area = livingRoom
        livingHumidity.area = livingRoom
        livingRoomAC.area = livingRoom

        bedsideLamp.area = bedroom
        readingLight.area = bedroom
        blackoutBlinds.area = bedroom
        bedroomDoor.area = bedroom
        nightMode.area = bedroom
        goodnightScene.area = bedroom
        morningScene.area = bedroom
        bedroomTemp.area = bedroom
        bedroomHumidity.area = bedroom
        bedroomHeater.area = bedroom

        kitchenLights.area = kitchen
        counterLights.area = kitchen
        rollerShutter.area = kitchen
        kitchenSmoke.area = kitchen
        coffeeMachine.area = kitchen
        cookingScene.area = kitchen
        kitchenTemp.area = kitchen
        kitchenHumidity.area = kitchen

        bathroomLight.area = bathroom
        mirrorLight.area = bathroom
        bathroomWindow.area = bathroom
        bathroomTemp.area = bathroom
        bathroomHumidity.area = bathroom

        deskLamp.area = office
        officeOverhead.area = office
        officeBlinds.area = office
        officeOccupancy.area = office
        deskFan.area = office
        focusScene.area = office
        restartRouter.area = office
        officeTemp.area = office
        officeHumidity.area = office

        gardenTemp.area = garden
        gardenHumidity.area = garden

        // MARK: - Unassigned Entities (no area)

        let hallwayLight = LightEntity(
            entityId: "light.hallway",
            name: "Hallway Light",
            state: .on,
            brightness: 180,
            supportedColorModes: ["brightness"],
            supportedFeaturesRaw: 0
        )

        let garageDoor = CoverEntity(
            entityId: "cover.garage_door",
            name: "Garage Door",
            state: .closed,
            currentPosition: 0,
            supportedFeaturesRaw: CoverEntity.Features.allDemo.rawValue,
            deviceClass: .garage
        )

        for entity in [hallwayLight, garageDoor] as [any PersistentModel] {
            context.insert(entity)
        }
        // Intentionally NOT assigning .area — these appear in the "Other" section

        // MARK: - Home Tiles (pre-pinned)

        context.insert(HomeTile(entityId: ceilingLight.entityId, tileSize: .medium, sortOrder: 0))
        context.insert(HomeTile(entityId: blinds.entityId, tileSize: .medium, sortOrder: 1))
        context.insert(HomeTile(entityId: floorLamp.entityId, tileSize: .small, sortOrder: 2))
        context.insert(HomeTile(entityId: livingRoomAC.entityId, tileSize: .small, sortOrder: 3))
        context.insert(HomeTile(entityId: tvBacklight.entityId, tileSize: .medium, sortOrder: 4))
        context.insert(HomeTile(entityId: bedsideLamp.entityId, tileSize: .small, sortOrder: 5))
        context.insert(HomeTile(entityId: motionLights.entityId, tileSize: .small, sortOrder: 6))
        context.insert(HomeTile(entityId: blackoutBlinds.entityId, tileSize: .small, sortOrder: 7))
        context.insert(HomeTile(entityId: kitchenLights.entityId, tileSize: .small, sortOrder: 8))
        context.insert(HomeTile(entityId: officeOverhead.entityId, tileSize: .small, sortOrder: 9))
        context.insert(HomeTile(entityId: deskLamp.entityId, tileSize: .small, sortOrder: 10))
        context.insert(HomeTile(entityId: nightMode.entityId, tileSize: .small, sortOrder: 11))

        try? context.save()
    }
}

// MARK: - Convenience

private extension CoverEntity.Features {
    static let allDemo: CoverEntity.Features = [.open, .close, .stop, .setPosition]
}
