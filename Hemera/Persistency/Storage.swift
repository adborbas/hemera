import TileGridEngine

protocol Storage {
    func areas() -> [AreaEntity]

    // MARK: - Home Tiles
    func homeTiles() -> [HomeTile]
    @discardableResult func addHomeTile(entityId: String) -> HomeTile
    func removeHomeTile(entityId: String)
    func updateHomeTileSortOrders(_ updates: [(entityId: String, sortOrder: Int)])
    func updateHomeTileLayout(_ updates: [(entityId: String, sortOrder: Int, size: TileSize)])
}
