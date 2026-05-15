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
}
