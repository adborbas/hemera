import TileGridEngine
import Testing
import Foundation

// MARK: - Scenario

final class TileGridEngineTestScenario {
    private(set) var engine: TileGridEngine
    let originalOrder: [String]

    /// Current order is defined as the row-major order of tile origins in the engine's 2D grid.
    var currentOrder: [String] {
        Self.order(from: engine.effectiveCells, tilesByID: engine.tilesByID, columns: engine.columns)
    }

    /// Expose drag state for tests that need to assert on it.
    var draggingID: Tile.ID? {
        engine.draggingID
    }

    // MARK: - Trace (only shown on failure)

    private var traceSteps: [String] = []
    private var traceCounter: Int = 0

    private func record(_ action: String) {
        let header = "Step \(traceCounter): \(action)"
        traceCounter += 1
        traceSteps.append(header + "\n" + engine.debugString())
    }

    private var trace: String {
        traceSteps.joined(separator: "\n\n")
    }

    // MARK: - Initializers

    /// Initializes a scenario from a simple 1D list of tiles ("A:s", "B:m", ...).
    ///
    /// This constructor uses a deterministic first-fit packing builder to create the engine's 2D grid.
    init(_ tiles: [String], columns: Int) {
        let parsedTiles: [Tile] = tiles.map { rawTile in
            let components = rawTile.split(separator: ":")
            let title = components.first!
            let size: TileSize = {
                switch rawTile.last {
                case "s": return .small
                case "m": return .medium
                case "l": return .large
                default: fatalError("Wrong size")
                }
            }()
            return Tile(title: String(title), size: size)
        }

        let packed = Self.packTiles(parsedTiles, columns: columns)
        self.engine = TileGridEngine(columns: columns, cells: packed, tiles: parsedTiles)
        self.originalOrder = Self.order(from: packed, tilesByID: engine.tilesByID, columns: columns)
        record("initial")
    }

    private init(engine: TileGridEngine, originalOrder: [String]) {
        self.engine = engine
        self.originalOrder = originalOrder
        record("initial")
    }

    // MARK: - Actions

    func beginDragging(_ title: String) {
        guard let id = engine.tilesByID.values.first(where: { $0.title == title })?.id else {
            // Non-existing tile is a no-op in the engine.
            engine.beginDrag(tileID: UUID())
            record("beginDragging(\(title))")
            return
        }
        engine.beginDrag(tileID: id)
        record("beginDragging(\(title))")
    }

    func hover(over title: String?) {
        guard let title else {
            engine.hover(over: nil)
            record("hover(over: nil)")
            return
        }
        guard let id = engine.tilesByID.values.first(where: { $0.title == title })?.id else {
            engine.hover(over: nil)
            record("hover(over: \(title)) -> nil (unknown)")
            return
        }
        engine.hover(over: id)
        record("hover(over: \(title))")
    }

    func endDrag(commit: Bool = true) {
        engine.endDrag(commit: commit)
        record("endDrag(commit: \(commit))")
    }

    func expectOrder(_ expected: [String]) {
        #expect(currentOrder == expected)
    }
}

// MARK: - DSL factories + expectations

extension TileGridEngineTestScenario {
    /// Convenience factory to build a scenario from a 2D grid of logical cells.
    ///
    /// - Important: `columns` is expressed in engine columns (old grid units).
    ///   - 1 logical cell == 2 engine columns
    static func grid(columns columnsInput: Int, rows: [[GridCellSpec]]) -> TileGridEngineTestScenario {
        let engineColumns = columnsInput
        precondition(engineColumns > 0, "columns must be > 0")
        precondition(engineColumns % 2 == 0, "engine columns must be even because 1 logical cell == 2 engine columns")

        let logicalColumns = engineColumns / 2
        let rowLogicalWidth = rows.first?.count ?? 0
        precondition(rowLogicalWidth > 0 || rows.isEmpty, "rows must not be empty")
        precondition(rowLogicalWidth == logicalColumns, "Row width (\(rowLogicalWidth)) must equal logicalColumns (engineColumns/2 = \(logicalColumns)). Provided engine columns: \(engineColumns)")
        precondition(rows.allSatisfy { $0.count == logicalColumns }, "All rows must have exactly \(logicalColumns) logical cells")

        // 1) Create tiles from top-left occurrences.
        var tilesByTitle: [String: Tile] = [:]
        for r in 0..<rows.count {
            for c in 0..<logicalColumns {
                switch rows[r][c] {
                case .small(let title):
                    if tilesByTitle[title] == nil { tilesByTitle[title] = Tile(title: title, size: .small) }
                case .medium(let title):
                    if tilesByTitle[title] == nil { tilesByTitle[title] = Tile(title: title, size: .medium) }
                case .large(let title):
                    if tilesByTitle[title] == nil { tilesByTitle[title] = Tile(title: title, size: .large) }
                case .span, .gap:
                    continue
                }
            }
        }

        let tiles = Array(tilesByTitle.values)

        // 2) Build engine cells (old units), starting empty.
        var cells: [[TileGridEngine.Cell]] = Array(
            repeating: Array(repeating: .empty, count: engineColumns),
            count: rows.count
        )

        // Helper to map logical col -> old-unit col.
        func oldCol(_ logicalCol: Int) -> Int { logicalCol * 2 }

        // 3) For each declared origin, validate spans in the logical grid and fill engine cells.
        for r in 0..<rows.count {
            for c in 0..<logicalColumns {
                let spec = rows[r][c]

                let pair: (title: String, size: TileSize)?
                switch spec {
                case .small(let t):
                    pair = (t, .small)
                case .medium(let t):
                    pair = (t, .medium)
                case .large(let t):
                    pair = (t, .large)
                case .span, .gap:
                    pair = nil
                }

                guard let pair else { continue }
                let title = pair.title
                let size = pair.size

                guard let tile = tilesByTitle[title] else { continue }

                // Derive logical footprint.
                let logicalSpanX: Int
                switch size {
                case .large: logicalSpanX = 2
                case .small, .medium: logicalSpanX = 1
                }
                let logicalSpanY: Int = size.spanY

                // Validate footprint in logical coordinates.
                precondition(r + logicalSpanY <= rows.count, "Tile '\(title)' exceeds grid height")
                precondition(c + logicalSpanX <= logicalColumns, "Tile '\(title)' exceeds grid width")

                for dy in 0..<logicalSpanY {
                    for dx in 0..<logicalSpanX {
                        let rr = r + dy
                        let cc = c + dx
                        if dy == 0 && dx == 0 {
                            // origin cell must match.
                            precondition(rows[rr][cc].titleIfAny == title, "Expected origin for '\(title)' at (\(r),\(c))")
                        } else {
                            // span cells must be explicitly marked.
                            precondition(rows[rr][cc] == .span(of: title), "Expected span(of: '\(title)') at (\(rr),\(cc))")
                        }
                    }
                }

                // Fill engine cells in old units.
                let originRow = r
                let originColOld = oldCol(c)
                let spanXOld = size.spanX
                let spanYOld = size.spanY

                // Place origin.
                precondition(isEmpty(cells[originRow][originColOld]), "Cell already occupied at (\(originRow),\(originColOld))")
                cells[originRow][originColOld] = .origin(tile.id)

                // Fill remaining covered old-unit cells.
                for yy in originRow..<(originRow + spanYOld) {
                    for xx in originColOld..<(originColOld + spanXOld) {
                        if yy == originRow && xx == originColOld { continue }
                        precondition(isEmpty(cells[yy][xx]), "Cell already occupied at (\(yy),\(xx))")
                        cells[yy][xx] = .span(tile.id)
                    }
                }
            }
        }

        let engine = TileGridEngine(columns: engineColumns, cells: cells, tiles: tiles)
        let originalOrder = Self.order(from: cells, tilesByID: engine.tilesByID, columns: engineColumns)
        return TileGridEngineTestScenario(engine: engine, originalOrder: originalOrder)
    }

    /// Validates the engine's current 2D grid against a 2D grid of logical cells.
    ///
    /// - Important: expected grid is expressed in logical columns (old columns / 2).
    func expectGridCells(_ expected: [[GridCellSpec]]) {
        let grid = engine.effectiveCells
        let logicalColumns = engine.columns / 2

        // Convert engine old-unit cells into logical GridCellSpec.
        var actual: [[GridCellSpec]] = Array(
            repeating: Array(repeating: .gap, count: logicalColumns),
            count: grid.count
        )

        // Build logical cells by scanning old-unit origins and filling spans.
        for r in 0..<grid.count {
            for cOld in 0..<engine.columns {
                guard case .origin(let id) = grid[r][cOld] else { continue }
                guard let tile = engine.tilesByID[id] else { continue }

                let title = tile.title
                let size = tile.size

                let cLogical = cOld / 2
                let logicalSpanX: Int
                switch size {
                case .large: logicalSpanX = 2
                case .small, .medium: logicalSpanX = 1
                }
                let logicalSpanY: Int = size.spanY

                // Place origin.
                switch size {
                case .small:  actual[r][cLogical] = .small(title)
                case .medium: actual[r][cLogical] = .medium(title)
                case .large:  actual[r][cLogical] = .large(title)
                }

                // Place spans.
                for dy in 0..<logicalSpanY {
                    for dx in 0..<logicalSpanX {
                        if dy == 0 && dx == 0 { continue }
                        let rr = r + dy
                        let cc = cLogical + dx
                        if rr < actual.count, cc < actual[rr].count {
                            actual[rr][cc] = .span(of: title)
                        }
                    }
                }
            }
        }

        // Validate dimensions first.
        guard actual.count == expected.count else {
            #expect(Bool(false), "Row count mismatch. Actual: \(actual.count), expected: \(expected.count)\n\nTrace:\n\(trace)")
            return
        }
        let expectedWidth = expected.first?.count ?? 0
        guard expectedWidth > 0 else {
            #expect(Bool(false), "Expected grid must have at least 1 column.\n\nTrace:\n\(trace)")
            return
        }
        guard actual.allSatisfy({ $0.count == expectedWidth }) else {
            #expect(Bool(false), "Actual grid has inconsistent row widths.\n\nTrace:\n\(trace)")
            return
        }
        guard actual.first?.count == expectedWidth else {
            #expect(Bool(false), "Column count mismatch. Actual: \(actual.first?.count ?? -1), expected: \(expectedWidth)\n\nTrace:\n\(trace)")
            return
        }

        // Cell-by-cell, fail fast with a useful message.
        for (rowIndex, (actualRow, expectedRow)) in zip(actual, expected).enumerated() {
            for (colIndex, (actualCell, expectedCell)) in zip(actualRow, expectedRow).enumerated() {
                if actualCell != expectedCell {
                    #expect(
                        Bool(false),
                        Comment(stringLiteral:
                            "Cell mismatch at (\(rowIndex), \(colIndex)).\n" +
                            "Actual: \(actualCell)\n" +
                            "Expected: \(expectedCell)\n\n" +
                            "Trace:\n\(trace)"
                        )
                    )
                    return
                }
            }
        }
    }
}

// MARK: - Packing + ordering helpers

private extension TileGridEngineTestScenario {

    static func order(from grid: [[TileGridEngine.Cell]], tilesByID: [Tile.ID: Tile], columns: Int) -> [String] {
        var result: [String] = []
        for r in 0..<grid.count {
            for c in 0..<columns {
                if case .origin(let id) = grid[r][c], let tile = tilesByID[id] {
                    result.append(tile.title)
                }
            }
        }
        return result
    }

    static func isEmpty(_ cell: TileGridEngine.Cell) -> Bool {
        if case .empty = cell { return true }
        return false
    }

    static func packTiles(_ tiles: [Tile], columns: Int) -> [[TileGridEngine.Cell]] {
        precondition(columns > 0)

        var grid: [[TileGridEngine.Cell]] = [Array(repeating: .empty, count: columns)]

        func ensureRows(_ count: Int) {
            while grid.count < count {
                grid.append(Array(repeating: .empty, count: columns))
            }
        }

        func canPlace(tile: Tile, atRow r: Int, col c: Int) -> Bool {
            let spanX = tile.size.spanX
            let spanY = tile.size.spanY
            guard c >= 0, r >= 0 else { return false }
            guard c + spanX <= columns else { return false }
            ensureRows(r + spanY)

            for yy in r..<(r + spanY) {
                for xx in c..<(c + spanX) {
                    if !isEmpty(grid[yy][xx]) { return false }
                }
            }
            return true
        }

        func place(tile: Tile, atRow r: Int, col c: Int) {
            let spanX = tile.size.spanX
            let spanY = tile.size.spanY
            ensureRows(r + spanY)

            grid[r][c] = .origin(tile.id)
            for yy in r..<(r + spanY) {
                for xx in c..<(c + spanX) {
                    if yy == r && xx == c { continue }
                    grid[yy][xx] = .span(tile.id)
                }
            }
        }

        for tile in tiles {
            var placed = false
            var r = 0
            while !placed {
                ensureRows(r + tile.size.spanY)
                for c in 0..<columns {
                    if canPlace(tile: tile, atRow: r, col: c) {
                        place(tile: tile, atRow: r, col: c)
                        placed = true
                        break
                    }
                }
                if !placed { r += 1 }
            }
        }

        return grid
    }
}
