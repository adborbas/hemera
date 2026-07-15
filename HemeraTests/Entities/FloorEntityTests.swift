import Foundation
import SwiftData
import Testing
@testable import Hemera

@MainActor
struct FloorEntityTests {

    let container: ModelContainer
    let context: ModelContext

    init() {
        let schema = Schema([AreaEntity.self, FloorEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    @Test
    func upsert_newFloor_inserts() {
        FloorEntity.upsert(id: "ground", name: "Ground Floor", level: 0, sortOrder: 0, in: context)

        let floors = try! context.fetch(FetchDescriptor<FloorEntity>())
        #expect(floors.count == 1)
        #expect(floors.first?.name == "Ground Floor")
        #expect(floors.first?.level == 0)
    }

    @Test
    func upsert_existingFloor_updatesInPlace() {
        let first = FloorEntity.upsert(id: "ground", name: "Ground", level: 0, sortOrder: 5, in: context)
        try! context.save()

        let second = FloorEntity.upsert(id: "ground", name: "Ground Floor", level: 1, sortOrder: 2, in: context)

        // Same object mutated, not a duplicate insert.
        #expect(first === second)
        #expect(second.name == "Ground Floor")
        #expect(second.level == 1)
        #expect(second.sortOrder == 2)

        let floors = try! context.fetch(FetchDescriptor<FloorEntity>())
        #expect(floors.count == 1)
    }

    @Test
    func upsert_nilLevel_isStored() {
        let floor = FloorEntity.upsert(id: "attic", name: "Attic", level: nil, sortOrder: 0, in: context)
        #expect(floor.level == nil)
    }
}
