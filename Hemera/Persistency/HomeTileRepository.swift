import Foundation
import TileGridEngine

/// Write access for home tile data.
///
/// Reads of `[HomeTile]` are now driven by `@Query` in views, so the
/// repository no longer exposes a reactive read surface — it just owns the
/// mutations.
@MainActor
protocol HomeTileRepository: AnyObject {
    func hasAnyHomeTile() -> Bool
    func isOnHome(entityId: String) -> Bool
    func addToHome(entityId: String)
    func removeFromHome(entityId: String)
    func reorderHomeTiles(_ updates: [(entityId: String, sortOrder: Int)])
    func commitHomeTileLayout(_ updates: [(entityId: String, sortOrder: Int, size: TileSize)])
}

/// SwiftData-backed home tile repository.
@MainActor
final class SwiftDataHomeTileRepository: HomeTileRepository {

    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    func hasAnyHomeTile() -> Bool {
        !storage.homeTiles().isEmpty
    }

    func isOnHome(entityId: String) -> Bool {
        storage.homeTiles().contains { $0.entityId == entityId }
    }

    func addToHome(entityId: String) {
        storage.addHomeTile(entityId: entityId)
    }

    func removeFromHome(entityId: String) {
        storage.removeHomeTile(entityId: entityId)
    }

    func reorderHomeTiles(_ updates: [(entityId: String, sortOrder: Int)]) {
        storage.updateHomeTileSortOrders(updates)
    }

    func commitHomeTileLayout(_ updates: [(entityId: String, sortOrder: Int, size: TileSize)]) {
        storage.updateHomeTileLayout(updates)
    }
}
