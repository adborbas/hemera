import Testing
@testable import Hemera

struct AreaMappingResolverTests {

    private static let kitchen = AreaRegistryEntry(areaId: "kitchen", name: "Kitchen", floorId: nil)
    private static let bedroom = AreaRegistryEntry(areaId: "bedroom", name: "Bedroom", floorId: nil)

    /// Home Assistant lets an entity override the area it would take from its device.
    @Test func resolve_entityWithOwnArea_winsOverItsDeviceArea() {
        let mappings = AreaMappingResolver.resolve(
            areas: [Self.kitchen, Self.bedroom],
            entityAreaIds: ["light.lamp": "kitchen"],
            deviceMappings: [DeviceMapping(entityId: "light.lamp", deviceId: "dev-1")],
            devices: [DeviceRegistryEntry(deviceId: "dev-1", areaId: "bedroom")]
        )

        #expect(mappings.first { $0.areaId == "kitchen" }?.entities == ["light.lamp"])
        #expect(mappings.first { $0.areaId == "bedroom" }?.entities == [])
    }

    /// Entities without a name of their own cannot hold an area, so inheriting one is the common case.
    @Test func resolve_entityWithoutOwnArea_inheritsItsDeviceArea() {
        let mappings = AreaMappingResolver.resolve(
            areas: [Self.kitchen],
            entityAreaIds: [:],
            deviceMappings: [DeviceMapping(entityId: "light.lamp", deviceId: "dev-1")],
            devices: [DeviceRegistryEntry(deviceId: "dev-1", areaId: "kitchen")]
        )

        #expect(mappings.map(\.entities) == [["light.lamp"]])
    }

    /// Nothing places it, so it has to fall through to the unassigned bucket.
    @Test func resolve_entityWhoseDeviceHasNoArea_appearsInNoMapping() {
        let mappings = AreaMappingResolver.resolve(
            areas: [Self.kitchen],
            entityAreaIds: [:],
            deviceMappings: [DeviceMapping(entityId: "light.lamp", deviceId: "dev-1")],
            devices: [DeviceRegistryEntry(deviceId: "dev-1", areaId: nil)]
        )

        #expect(mappings.flatMap(\.entities).isEmpty)
    }

    /// An area the user created but has not filled yet must still render.
    @Test func resolve_areaWithNoEntities_isStillReturned() {
        let mappings = AreaMappingResolver.resolve(
            areas: [Self.kitchen, Self.bedroom],
            entityAreaIds: ["light.lamp": "kitchen"],
            deviceMappings: [],
            devices: []
        )

        #expect(mappings.count == 2)
        #expect(mappings[1].areaId == "bedroom")
        #expect(mappings[1].entities.isEmpty)
    }

    @Test func resolve_areaIdMissingFromRegistry_isIgnored() {
        let mappings = AreaMappingResolver.resolve(
            areas: [Self.kitchen],
            entityAreaIds: ["light.ghost": "demolished_room"],
            deviceMappings: [],
            devices: []
        )

        #expect(mappings.map(\.areaId) == ["kitchen"])
        #expect(mappings.flatMap(\.entities).isEmpty)
    }

    /// Registry order is what drives the order areas are displayed in.
    @Test func resolve_mappings_followRegistryOrder() {
        let office = AreaRegistryEntry(areaId: "office", name: "Office", floorId: nil)
        let mappings = AreaMappingResolver.resolve(
            areas: [Self.bedroom, office, Self.kitchen],
            entityAreaIds: [:],
            deviceMappings: [],
            devices: []
        )

        #expect(mappings.map(\.areaId) == ["bedroom", "office", "kitchen"])
    }

    /// A stable order stops the card grid reshuffling on every sync.
    @Test func resolve_entitiesWithinAnArea_areSorted() {
        let mappings = AreaMappingResolver.resolve(
            areas: [Self.kitchen],
            entityAreaIds: ["light.sink": "kitchen", "light.ceiling": "kitchen"],
            deviceMappings: [],
            devices: []
        )

        #expect(mappings[0].entities == ["light.ceiling", "light.sink"])
    }

    @Test func resolve_areaNames_comeFromTheAreaRegistry() {
        let mappings = AreaMappingResolver.resolve(
            areas: [Self.kitchen],
            entityAreaIds: [:],
            deviceMappings: [],
            devices: []
        )

        #expect(mappings[0].areaName == "Kitchen")
    }
}
