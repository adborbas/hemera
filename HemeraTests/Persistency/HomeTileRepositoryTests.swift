import Foundation
import SwiftData
import TileGridEngine
import Testing
@testable import Hemera

@MainActor
struct HomeTileRepositoryTests {

    let container: ModelContainer
    let context: ModelContext
    let storage: SwiftDataStorage
    let repo: SwiftDataHomeTileRepository

    init() {
        let schema = Schema([HomeTile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        storage = SwiftDataStorage(context: context)
        repo = SwiftDataHomeTileRepository(storage: storage)
    }

    @Test
    func hasAnyHomeTile_withNoTiles_returnsFalse() {
        #expect(repo.hasAnyHomeTile() == false)
    }

    @Test
    func hasAnyHomeTile_afterAdd_returnsTrue() {
        repo.addToHome(entityId: "light.lamp")
        #expect(repo.hasAnyHomeTile() == true)
    }

    @Test
    func isOnHome_whenTileExists_returnsTrue() {
        repo.addToHome(entityId: "light.lamp")
        #expect(repo.isOnHome(entityId: "light.lamp") == true)
    }

    @Test
    func isOnHome_whenTileMissing_returnsFalse() {
        #expect(repo.isOnHome(entityId: "light.lamp") == false)
    }

    @Test
    func addToHome_persistsTileInStorage() {
        repo.addToHome(entityId: "light.lamp")
        let tiles = storage.homeTiles()
        #expect(tiles.count == 1)
        #expect(tiles.first?.entityId == "light.lamp")
    }

    @Test
    func removeFromHome_deletesTileFromStorage() {
        repo.addToHome(entityId: "light.lamp")
        repo.removeFromHome(entityId: "light.lamp")
        #expect(storage.homeTiles().isEmpty)
        #expect(repo.isOnHome(entityId: "light.lamp") == false)
    }

    @Test
    func reorderHomeTiles_updatesSortOrders() {
        repo.addToHome(entityId: "light.a")
        repo.addToHome(entityId: "light.b")

        repo.reorderHomeTiles([
            (entityId: "light.b", sortOrder: 0),
            (entityId: "light.a", sortOrder: 1)
        ])

        let tiles = storage.homeTiles()
        #expect(tiles[0].entityId == "light.b")
        #expect(tiles[1].entityId == "light.a")
    }

    @Test
    func commitHomeTileLayout_updatesSortOrderAndSize() {
        repo.addToHome(entityId: "light.a")
        repo.commitHomeTileLayout([
            (entityId: "light.a", sortOrder: 2, size: .medium)
        ])

        let tile = storage.homeTiles().first
        #expect(tile?.sortOrder == 2)
        #expect(tile?.tileSize == .medium)
    }
}
