import SwiftData
import Foundation
import HemeraLog
import TileGridEngine

@MainActor
final class SwiftDataStorage: Storage {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func areas() -> [AreaEntity] {
        let descriptor = FetchDescriptor<AreaEntity>(
            sortBy: [SortDescriptor(\AreaEntity.sortOrder)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.warning("Failed to fetch areas", cause: error)
            return []
        }
    }

    // MARK: - Home Tiles

    func homeTiles() -> [HomeTile] {
        let descriptor = FetchDescriptor<HomeTile>(
            sortBy: [SortDescriptor(\HomeTile.sortOrder)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.warning("Failed to fetch home tiles", cause: error)
            return []
        }
    }

    @discardableResult
    func addHomeTile(entityId: String) -> HomeTile {
        if let existing = findHomeTile(entityId: entityId) {
            return existing
        }

        let allTiles = homeTiles()
        let maxSort = allTiles.last?.sortOrder ?? -1
        let tile = HomeTile(entityId: entityId, sortOrder: maxSort + 1)
        context.insert(tile)
        saveOrLog("add home tile")
        return tile
    }

    func removeHomeTile(entityId: String) {
        if let tile = findHomeTile(entityId: entityId) {
            context.delete(tile)
            saveOrLog("remove home tile")
        }
    }

    func updateHomeTileSortOrders(_ updates: [(entityId: String, sortOrder: Int)]) {
        let tiles = homeTiles()
        for (entityId, sortOrder) in updates {
            if let tile = tiles.first(where: { $0.entityId == entityId }) {
                tile.sortOrder = sortOrder
            }
        }
        saveOrLog("update home tile sort orders")
    }

    func updateHomeTileLayout(_ updates: [(entityId: String, sortOrder: Int, size: TileSize)]) {
        let tiles = homeTiles()
        for (entityId, sortOrder, size) in updates {
            if let tile = tiles.first(where: { $0.entityId == entityId }) {
                tile.sortOrder = sortOrder
                tile.tileSize = size
            }
        }
        saveOrLog("update home tile layout")
    }

    // MARK: - Private

    private func findHomeTile(entityId: String) -> HomeTile? {
        homeTiles().first { $0.entityId == entityId }
    }

    private func saveOrLog(_ description: String) {
        do {
            try context.save()
        } catch {
            Log.error("Failed to save after \(description)", cause: error)
        }
    }
}
