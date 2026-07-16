import SwiftData
import TileGridEngine

@Model
final class HomeTile {
    @Attribute(.unique)
    var entityId: String

    var sortOrder: Int
    var tileSizeRaw: String

    var tileSize: TileSize {
        get {
            switch tileSizeRaw {
            case "medium": .medium
            case "large": .large
            default: .small
            }
        }
        set {
            switch newValue {
            case .small: tileSizeRaw = "small"
            case .medium: tileSizeRaw = "medium"
            case .large: tileSizeRaw = "large"
            }
        }
    }

    init(entityId: String, tileSize: TileSize = .small, sortOrder: Int) {
        self.entityId = entityId
        self.sortOrder = sortOrder
        self.tileSizeRaw = "small"
        self.tileSize = tileSize
    }

    /// Deletes home tiles whose entity is no longer present on the server.
    /// Called on sync completion against the set of entity ids the server reported.
    /// Keyed on entity presence (not `isAvailable`) so a merely-`"unavailable"` entity
    /// keeps its tile; only an entity entirely absent from the sync is pruned. Skips
    /// pruning when the set is empty (a suspect/failed sync).
    static func pruneOrphaned(keeping serverEntityIds: Set<String>, in context: ModelContext) {
        guard !serverEntityIds.isEmpty else { return }
        guard let tiles = try? context.fetch(FetchDescriptor<HomeTile>()) else { return }
        for tile in tiles where !serverEntityIds.contains(tile.entityId) {
            context.delete(tile)
        }
    }
}
