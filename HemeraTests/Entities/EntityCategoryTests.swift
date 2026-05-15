import Testing
@testable import Hemera

@MainActor
struct EntityCategoryTests {

    @Test func from_mapsDomainsToCategories() {
        #expect(EntityCategory.from(entityId: "light.living_room") == .lights)
        #expect(EntityCategory.from(entityId: "cover.blinds") == .covers)
        #expect(EntityCategory.from(entityId: "climate.ac") == .climate)
        #expect(EntityCategory.from(entityId: "switch.coffee") == .controls)
        #expect(EntityCategory.from(entityId: "button.restart") == .controls)
        #expect(EntityCategory.from(entityId: "scene.movie_night") == .controls)
        #expect(EntityCategory.from(entityId: "automation.motion_lights") == .controls)
        #expect(EntityCategory.from(entityId: "binary_sensor.motion") == .sensors)
    }

    @Test func from_returnsNilForUnsupportedOrMalformedIds() {
        #expect(EntityCategory.from(entityId: "sensor.temperature") == nil)
        #expect(EntityCategory.from(entityId: "media_player.tv") == nil)
        #expect(EntityCategory.from(entityId: "nodot") == nil)
        #expect(EntityCategory.from(entityId: "") == nil)
    }

    @Test func allCases_orderedCorrectly() {
        #expect(EntityCategory.allCases == [.lights, .covers, .climate, .controls, .sensors])
    }

    @Test func title_matchesExpectedStrings() {
        #expect(EntityCategory.lights.title == "Lights")
        #expect(EntityCategory.covers.title == "Covers")
        #expect(EntityCategory.climate.title == "Climate")
        #expect(EntityCategory.controls.title == "Controls")
        #expect(EntityCategory.sensors.title == "Sensors")
    }
}
