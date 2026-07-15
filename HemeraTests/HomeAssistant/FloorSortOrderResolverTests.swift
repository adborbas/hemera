import Testing
@testable import Hemera

struct FloorSortOrderResolverTests {

    // MARK: - Empty Input

    @Test func resolve_emptyFloors_returnsEmpty() {
        let result = FloorSortOrderResolver.resolve(floors: [])
        #expect(result.isEmpty)
    }

    // MARK: - Level Ordering

    @Test func resolve_ascendingLevels_ordersByLevel() {
        // Registry order deliberately out of level order.
        let floors = [
            FloorRegistryEntry(floorId: "upper", name: "Upper", level: 2),
            FloorRegistryEntry(floorId: "ground", name: "Ground", level: 0),
            FloorRegistryEntry(floorId: "mezzanine", name: "Mezzanine", level: 1),
        ]
        let result = FloorSortOrderResolver.resolve(floors: floors)

        #expect(result["ground"] == 0)
        #expect(result["mezzanine"] == 1)
        #expect(result["upper"] == 2)
    }

    @Test func resolve_negativeLevel_sortsBelowGround() {
        let floors = [
            FloorRegistryEntry(floorId: "ground", name: "Ground", level: 0),
            FloorRegistryEntry(floorId: "basement", name: "Basement", level: -1),
            FloorRegistryEntry(floorId: "upper", name: "Upper", level: 1),
        ]
        let result = FloorSortOrderResolver.resolve(floors: floors)

        #expect(result["basement"] == 0)
        #expect(result["ground"] == 1)
        #expect(result["upper"] == 2)
    }

    // MARK: - Missing Levels

    @Test func resolve_missingLevels_fallBackToRegistryOrderAfterLeveled() {
        let floors = [
            FloorRegistryEntry(floorId: "attic", name: "Attic", level: nil),
            FloorRegistryEntry(floorId: "ground", name: "Ground", level: 0),
            FloorRegistryEntry(floorId: "shed", name: "Shed", level: nil),
        ]
        let result = FloorSortOrderResolver.resolve(floors: floors)

        // Leveled floor first; nil-level floors keep their registry order after it.
        #expect(result["ground"] == 0)
        #expect(result["attic"] == 1)
        #expect(result["shed"] == 2)
    }

    // MARK: - Duplicate Levels

    @Test func resolve_duplicateLevels_preserveRegistryOrder() {
        let floors = [
            FloorRegistryEntry(floorId: "west", name: "West Wing", level: 1),
            FloorRegistryEntry(floorId: "east", name: "East Wing", level: 1),
        ]
        let result = FloorSortOrderResolver.resolve(floors: floors)

        #expect(result["west"] == 0)
        #expect(result["east"] == 1)
    }

    @Test func resolve_allNilLevels_preserveRegistryOrder() {
        let floors = [
            FloorRegistryEntry(floorId: "a", name: "A", level: nil),
            FloorRegistryEntry(floorId: "b", name: "B", level: nil),
            FloorRegistryEntry(floorId: "c", name: "C", level: nil),
        ]
        let result = FloorSortOrderResolver.resolve(floors: floors)

        #expect(result == ["a": 0, "b": 1, "c": 2])
    }
}
