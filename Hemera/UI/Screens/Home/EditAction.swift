import TileGridEngine

enum EditAction {
    case resize(tileID: Tile.ID, oldSize: TileSize)
    case reorder(previousOrder: [Tile.ID])
}
