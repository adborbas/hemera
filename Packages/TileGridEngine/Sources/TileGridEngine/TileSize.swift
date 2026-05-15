import Foundation

/// Represents the size category of a tile in the grid.
///
/// Each size has a specific grid footprint defined by spanX (width) and spanY (height).
public enum TileSize: Equatable, Sendable {
    case small   // 2x1
    case medium  // 2x2
    case large   // 4x4

    /// Width in grid units.
    public var spanX: Int {
        switch self {
        case .small, .medium:
            return 2
        case .large:
            return 4
        }
    }

    /// Height in grid units.
    public var spanY: Int {
        switch self {
        case .small:
            return 1
        case .medium:
            return 2
        case .large:
            return 4
        }
    }
}
