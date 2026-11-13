import TileGridEngine

enum EditAction {
    case resize(tileID: Tile.ID, oldSize: TileSize)
    case reorder(previousOrder: [Tile.ID])
    case remove(tileID: Tile.ID)
    case restore(tile: Tile, index: Int)
}
