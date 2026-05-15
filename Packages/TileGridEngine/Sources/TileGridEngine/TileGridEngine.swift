import Foundation

/// A pure, layout-agnostic grid engine with iOS-style slide/shift reordering.
///
/// The engine's canonical state is an **ordered tile array**. The 2D grid
/// is derived from this order using a stable layout algorithm.
///
/// Grid units:
/// - small = 2x1
/// - medium = 2x2
/// - large = 4x4
///
/// The UI is responsible for turning these grid units into pixels.
public struct TileGridEngine: Sendable {

    // MARK: - Public types

    public enum Cell: Equatable, Sendable {
        case empty
        case origin(Tile.ID)
        case span(Tile.ID)

        public var tileID: Tile.ID? {
            switch self {
            case .empty: return nil
            case .origin(let id), .span(let id): return id
            }
        }
    }

    public struct Placement: Equatable, Sendable {
        public let id: Tile.ID
        public let row: Int
        public let column: Int
        public let spanX: Int
        public let spanY: Int
    }

    public struct Snapshot: Equatable, Sendable {
        public let columns: Int
        public let rowCount: Int
        public let placements: [Placement]
        public let draggingID: Tile.ID?
    }

    // MARK: - Public state

    public let columns: Int

    /// Canonical state: ordered tile array.
    public private(set) var tiles: [Tile]

    /// Derived state: 2D grid computed from tiles via layout.
    public private(set) var cells: [[Cell]]

    /// Fast lookup by ID.
    public private(set) var tilesByID: [Tile.ID: Tile]

    /// The tile currently being dragged, if any.
    public private(set) var draggingID: Tile.ID?

    // MARK: - Drag state

    private struct DragState: Sendable {
        let originalOrder: [Tile]
        var workingOrder: [Tile]
        var lastTargetID: Tile.ID?
    }

    private var dragState: DragState?

    // MARK: - Init

    /// Creates an engine from an ordered tile array.
    ///
    /// - Parameters:
    ///   - columns: Number of columns in grid units.
    ///   - tiles: Ordered array of tiles.
    public init(columns: Int, tiles: [Tile]) {
        precondition(columns > 0, "columns must be > 0")

        self.columns = columns
        self.tiles = tiles
        self.tilesByID = Dictionary(uniqueKeysWithValues: tiles.map { ($0.id, $0) })
        self.cells = Self.layoutTiles(tiles, columns: columns)
    }

    /// Creates an engine from an explicit 2D grid (legacy compatibility).
    ///
    /// The tile order is extracted from the grid in row-major order.
    public init(columns: Int, cells: [[Cell]], tiles: [Tile]) {
        precondition(columns > 0, "columns must be > 0")
        precondition(cells.allSatisfy { $0.count == columns }, "All rows must have exactly `columns` cells")

        self.columns = columns
        self.tilesByID = Dictionary(uniqueKeysWithValues: tiles.map { ($0.id, $0) })

        // Extract tile order from grid (row-major order of origins)
        var orderedTiles: [Tile] = []
        for row in cells {
            for cell in row {
                if case .origin(let id) = cell, let tile = self.tilesByID[id] {
                    if !orderedTiles.contains(where: { $0.id == id }) {
                        orderedTiles.append(tile)
                    }
                }
            }
        }

        self.tiles = orderedTiles
        self.cells = cells
    }

    // MARK: - Public API

    /// Current effective grid (committed or live during drag).
    public var effectiveCells: [[Cell]] {
        if let state = dragState {
            return Self.layoutTiles(state.workingOrder, columns: columns)
        }
        return cells
    }

    /// Begin dragging a tile.
    public mutating func beginDrag(tileID: Tile.ID) {
        guard tilesByID[tileID] != nil else { return }
        draggingID = tileID
        dragState = DragState(
            originalOrder: tiles,
            workingOrder: tiles,
            lastTargetID: nil
        )
    }

    /// Processes a hover event during an active drag.
    ///
    /// Uses iOS-style slide/shift: the dragged tile is removed from its position
    /// and inserted at the target's position, causing other tiles to shift.
    ///
    /// Toggle semantics: hovering the same target twice reverts to original order.
    ///
    /// - Parameter tileID: The tile being hovered over, or `nil` if over empty space.
    public mutating func hover(over tileID: Tile.ID?) {
        guard let draggingID, var state = dragState else { return }
        guard let tileID, tileID != draggingID else { return }
        guard tilesByID[tileID] != nil else { return }

        var order = state.workingOrder

        // Find indices in current working order
        guard let draggedIndex = order.firstIndex(where: { $0.id == draggingID }),
              let targetIndex = order.firstIndex(where: { $0.id == tileID })
        else { return }

        // Toggle: if same target as last hover, revert to original
        if state.lastTargetID == tileID {
            state.workingOrder = state.originalOrder
            state.lastTargetID = nil
            dragState = state
            return
        }

        // Remove dragged tile from current position
        let draggedTile = order.remove(at: draggedIndex)

        // Insert at target position
        order.insert(draggedTile, at: targetIndex)

        state.workingOrder = order
        state.lastTargetID = tileID
        dragState = state
    }

    /// End drag.
    public mutating func endDrag(commit: Bool) {
        if commit, let state = dragState {
            tiles = state.workingOrder
            cells = Self.layoutTiles(tiles, columns: columns)
            tilesByID = Dictionary(uniqueKeysWithValues: tiles.map { ($0.id, $0) })
        }
        dragState = nil
        draggingID = nil
    }

    /// Produces a renderable snapshot for UI.
    public func snapshot() -> Snapshot {
        let grid = effectiveCells

        // Find origins row-major.
        var placements: [Placement] = []
        let effectiveTiles = dragState?.workingOrder ?? tiles

        for r in 0..<grid.count {
            for c in 0..<columns {
                if case .origin(let id) = grid[r][c] {
                    if let tile = effectiveTiles.first(where: { $0.id == id }) {
                        placements.append(
                            Placement(
                                id: id,
                                row: r,
                                column: c,
                                spanX: tile.size.spanX,
                                spanY: tile.size.spanY
                            )
                        )
                    }
                }
            }
        }

        // Keep placements stable: sort row-major.
        placements.sort {
            if $0.row != $1.row { return $0.row < $1.row }
            return $0.column < $1.column
        }

        return Snapshot(
            columns: columns,
            rowCount: grid.count,
            placements: placements,
            draggingID: draggingID
        )
    }

    // MARK: - Layout

    /// Computes a 2D cell grid from an ordered tile array using stable layout.
    ///
    /// Uses a forward-only, row-major placement algorithm for predictable results.
    private static func layoutTiles(_ tiles: [Tile], columns: Int) -> [[Cell]] {
        guard columns > 0, !tiles.isEmpty else {
            return []
        }

        var grid: [[Cell]] = []

        func ensureRows(_ count: Int) {
            while grid.count < count {
                grid.append(Array(repeating: .empty, count: columns))
            }
        }

        func canPlace(spanX: Int, spanY: Int, atRow row: Int, col: Int) -> Bool {
            guard col >= 0, row >= 0 else { return false }
            guard col + spanX <= columns else { return false }
            ensureRows(row + spanY)

            for r in row..<(row + spanY) {
                for c in col..<(col + spanX) {
                    if case .empty = grid[r][c] {
                        continue
                    } else {
                        return false
                    }
                }
            }
            return true
        }

        func place(tile: Tile, atRow row: Int, col: Int) {
            let spanX = tile.size.spanX
            let spanY = tile.size.spanY
            ensureRows(row + spanY)

            grid[row][col] = .origin(tile.id)
            for r in row..<(row + spanY) {
                for c in col..<(col + spanX) {
                    if r == row && c == col { continue }
                    grid[r][c] = .span(tile.id)
                }
            }
        }

        // Stable layout: forward-only cursor
        var currentRow = 0
        var currentCol = 0

        for tile in tiles {
            let spanX = min(tile.size.spanX, columns)
            let spanY = tile.size.spanY

            // Find next available position
            while true {
                if currentCol + spanX > columns {
                    currentRow += 1
                    currentCol = 0
                    continue
                }

                ensureRows(currentRow + spanY)

                if canPlace(spanX: spanX, spanY: spanY, atRow: currentRow, col: currentCol) {
                    place(tile: tile, atRow: currentRow, col: currentCol)
                    currentCol += spanX
                    break
                } else {
                    currentCol += 1
                }
            }
        }

        return grid
    }
}

// MARK: - Debug

extension TileGridEngine {
    public func debugPrint() {
        print(debugString())
    }

    public func debugString() -> String {
        let grid = effectiveCells
        var result = ""
        for row in grid {
            var rowStr = ""
            for cell in row {
                switch cell {
                case .empty:
                    rowStr += "."
                case .origin(let id):
                    if let tile = tilesByID[id] {
                        rowStr += String(tile.title.prefix(1)).uppercased()
                    } else {
                        rowStr += "?"
                    }
                case .span(let id):
                    if let tile = tilesByID[id] {
                        rowStr += String(tile.title.prefix(1)).lowercased()
                    } else {
                        rowStr += "?"
                    }
                }
            }
            result += rowStr + "\n"
        }
        return result
    }
}
