import Foundation
import SwiftData
import Testing
@testable import Hemera

/**
 Tests reconciliation of `HomeTile` rows against the entities present in a sync.
 Exercises the helper `HADataSyncService.applySyncPayload` calls after computing
 `serverEntityIds`, without needing a live connection.
 */
@MainActor
struct HomeTilePruneTests {

    let container: ModelContainer
    let context: ModelContext

    init() {
        let schema = Schema([HomeTile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    @Test
    func pruneOrphaned_tileForRemovedEntity_isDeleted() throws {
        context.insert(HomeTile(entityId: "light.gone", sortOrder: 0))

        HomeTile.pruneOrphaned(keeping: ["light.present"], in: context)

        #expect(try context.fetch(FetchDescriptor<HomeTile>()).isEmpty)
    }

    @Test
    func pruneOrphaned_tileForPresentEntity_isKept() throws {
        context.insert(HomeTile(entityId: "light.present", sortOrder: 0))

        HomeTile.pruneOrphaned(keeping: ["light.present"], in: context)

        let tiles = try context.fetch(FetchDescriptor<HomeTile>())
        #expect(tiles.count == 1)
        #expect(tiles.first?.entityId == "light.present")
    }

    @Test
    func pruneOrphaned_mixedTiles_onlyOrphanDeleted() throws {
        context.insert(HomeTile(entityId: "light.present", sortOrder: 0))
        context.insert(HomeTile(entityId: "light.gone", sortOrder: 1))

        HomeTile.pruneOrphaned(keeping: ["light.present"], in: context)

        let tiles = try context.fetch(FetchDescriptor<HomeTile>())
        #expect(tiles.map(\.entityId) == ["light.present"])
    }

    /// A failed/empty entity fetch must never wipe a user's pinned tiles.
    @Test
    func pruneOrphaned_emptyServerSet_keepsTiles() throws {
        context.insert(HomeTile(entityId: "light.present", sortOrder: 0))

        HomeTile.pruneOrphaned(keeping: [], in: context)

        #expect(try context.fetch(FetchDescriptor<HomeTile>()).count == 1)
    }
}
