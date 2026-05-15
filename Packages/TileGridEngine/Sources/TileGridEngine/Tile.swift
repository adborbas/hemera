import Foundation

/// A tile that can be placed in the grid.
///
/// Tiles are identified by their UUID and have a display title and size.
public struct Tile: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public var size: TileSize

    public init(id: UUID = UUID(), title: String, size: TileSize) {
        self.id = id
        self.title = title
        self.size = size
    }
}
