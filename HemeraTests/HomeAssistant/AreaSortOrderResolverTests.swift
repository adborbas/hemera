import Testing
@testable import Hemera

struct AreaSortOrderResolverTests {

    // MARK: - Empty Input

    @Test func resolve_emptyAreasAndFloors_returnsEmpty() {
        let result = AreaSortOrderResolver.resolve(areas: [], floors: [])
        #expect(result.isEmpty)
    }

    @Test func resolve_emptyAreas_returnsEmpty() {
        let floors = [FloorRegistryEntry(floorId: "floor_1", name: "First", level: 1)]
        let result = AreaSortOrderResolver.resolve(areas: [], floors: floors)
        #expect(result.isEmpty)
    }

    // MARK: - No Floors

    @Test func resolve_areasWithNoFloors_preservesRegistryOrder() {
        let areas = [
            AreaRegistryEntry(areaId: "kitchen", floorId: nil),
            AreaRegistryEntry(areaId: "bedroom", floorId: nil),
            AreaRegistryEntry(areaId: "office", floorId: nil),
        ]
        let result = AreaSortOrderResolver.resolve(areas: areas, floors: [])

        #expect(result == ["kitchen": 0, "bedroom": 1, "office": 2])
    }

    // MARK: - Single Floor

    @Test func resolve_singleFloor_preservesRegistryOrder() {
        let areas = [
            AreaRegistryEntry(areaId: "kitchen", floorId: "ground"),
            AreaRegistryEntry(areaId: "living_room", floorId: "ground"),
        ]
        let floors = [FloorRegistryEntry(floorId: "ground", name: "Ground", level: 0)]
        let result = AreaSortOrderResolver.resolve(areas: areas, floors: floors)

        #expect(result == ["kitchen": 0, "living_room": 1])
    }

    // MARK: - Multi-Floor Ordering

    @Test func resolve_multipleFloors_preservesFloorRegistryOrder() {
        let areas = [
            AreaRegistryEntry(areaId: "basement_storage", floorId: "basement"),
            AreaRegistryEntry(areaId: "bedroom", floorId: "upper"),
            AreaRegistryEntry(areaId: "kitchen", floorId: "ground"),
        ]
        let floors = [
            FloorRegistryEntry(floorId: "basement", name: "Basement", level: -1),
            FloorRegistryEntry(floorId: "ground", name: "Ground", level: 0),
            FloorRegistryEntry(floorId: "upper", name: "Upper", level: 1),
        ]
        let result = AreaSortOrderResolver.resolve(areas: areas, floors: floors)

        // Floor registry order: Basement, Ground, Upper
        #expect(result["basement_storage"] == 0)
        #expect(result["kitchen"] == 1)
        #expect(result["bedroom"] == 2)
    }

    @Test func resolve_multipleAreasPerFloor_maintainsRegistryOrderWithinFloor() {
        let areas = [
            AreaRegistryEntry(areaId: "master_bed", floorId: "upper"),
            AreaRegistryEntry(areaId: "guest_bed", floorId: "upper"),
            AreaRegistryEntry(areaId: "kitchen", floorId: "ground"),
            AreaRegistryEntry(areaId: "living_room", floorId: "ground"),
        ]
        let floors = [
            FloorRegistryEntry(floorId: "ground", name: "Ground", level: 0),
            FloorRegistryEntry(floorId: "upper", name: "Upper", level: 1),
        ]
        let result = AreaSortOrderResolver.resolve(areas: areas, floors: floors)

        // Floor registry order: Ground first, Upper second
        // Within each floor, area registry order is preserved
        #expect(result["kitchen"] == 0)
        #expect(result["living_room"] == 1)
        #expect(result["master_bed"] == 2)
        #expect(result["guest_bed"] == 3)
    }

    // MARK: - Nil Level

    @Test func resolve_floorWithNilLevel_comesAfterFlooredAreas() {
        let areas = [
            AreaRegistryEntry(areaId: "kitchen", floorId: "ground"),
            AreaRegistryEntry(areaId: "garage", floorId: "unleveled"),
        ]
        let floors = [
            FloorRegistryEntry(floorId: "ground", name: "Ground", level: 0),
            FloorRegistryEntry(floorId: "unleveled", name: "Other", level: nil),
        ]
        let result = AreaSortOrderResolver.resolve(areas: areas, floors: floors)

        #expect(result["kitchen"] == 0)
        #expect(result["garage"] == 1)
    }

    // MARK: - Same Level

    @Test func resolve_floorsWithSameLevel_preservesRegistryOrder() {
        let areas = [
            AreaRegistryEntry(areaId: "west_room", floorId: "west_wing"),
            AreaRegistryEntry(areaId: "east_room", floorId: "east_wing"),
        ]
        let floors = [
            FloorRegistryEntry(floorId: "west_wing", name: "West Wing", level: 1),
            FloorRegistryEntry(floorId: "east_wing", name: "East Wing", level: 1),
        ]
        let result = AreaSortOrderResolver.resolve(areas: areas, floors: floors)

        // Registry order: West Wing first, East Wing second
        #expect(result["west_room"] == 0)
        #expect(result["east_room"] == 1)
    }

    // MARK: - Unassigned Areas

    @Test func resolve_unassignedAreas_comeAfterAllFlooredAreas() {
        let areas = [
            AreaRegistryEntry(areaId: "garden", floorId: nil),
            AreaRegistryEntry(areaId: "kitchen", floorId: "ground"),
            AreaRegistryEntry(areaId: "shed", floorId: nil),
        ]
        let floors = [
            FloorRegistryEntry(floorId: "ground", name: "Ground", level: 0),
        ]
        let result = AreaSortOrderResolver.resolve(areas: areas, floors: floors)

        #expect(result["kitchen"] == 0)
        #expect(result["garden"] == 1)
        #expect(result["shed"] == 2)
    }

    // MARK: - Non-Existent Floor

    @Test func resolve_areaWithNonExistentFloor_treatedAsUnassigned() {
        let areas = [
            AreaRegistryEntry(areaId: "kitchen", floorId: "ground"),
            AreaRegistryEntry(areaId: "mystery", floorId: "deleted_floor"),
        ]
        let floors = [
            FloorRegistryEntry(floorId: "ground", name: "Ground", level: 0),
        ]
        let result = AreaSortOrderResolver.resolve(areas: areas, floors: floors)

        #expect(result["kitchen"] == 0)
        #expect(result["mystery"] == 1)
    }

    // MARK: - Empty Floor List With Floor References

    @Test func resolve_areasReferencingFloors_withEmptyFloorList_treatedAsUnassigned() {
        let areas = [
            AreaRegistryEntry(areaId: "kitchen", floorId: "ground"),
            AreaRegistryEntry(areaId: "bedroom", floorId: "upper"),
            AreaRegistryEntry(areaId: "garden", floorId: nil),
        ]
        let result = AreaSortOrderResolver.resolve(areas: areas, floors: [])

        #expect(result == ["kitchen": 0, "bedroom": 1, "garden": 2])
    }

    // MARK: - Mixed Scenario

    @Test func resolve_mixedFlooredAndUnassigned_fullOrdering() {
        let areas = [
            AreaRegistryEntry(areaId: "garden", floorId: nil),
            AreaRegistryEntry(areaId: "bedroom", floorId: "upper"),
            AreaRegistryEntry(areaId: "bathroom", floorId: "upper"),
            AreaRegistryEntry(areaId: "kitchen", floorId: "ground"),
            AreaRegistryEntry(areaId: "living_room", floorId: "ground"),
            AreaRegistryEntry(areaId: "garage", floorId: nil),
        ]
        let floors = [
            FloorRegistryEntry(floorId: "ground", name: "Ground Floor", level: 0),
            FloorRegistryEntry(floorId: "upper", name: "Upper Floor", level: 1),
        ]
        let result = AreaSortOrderResolver.resolve(areas: areas, floors: floors)

        // Floor registry order: Ground first, Upper second
        // Within each floor, area registry order is preserved
        // Unassigned areas come last, in area registry order
        #expect(result["kitchen"] == 0)
        #expect(result["living_room"] == 1)
        #expect(result["bedroom"] == 2)
        #expect(result["bathroom"] == 3)
        #expect(result["garden"] == 4)
        #expect(result["garage"] == 5)
    }
}
