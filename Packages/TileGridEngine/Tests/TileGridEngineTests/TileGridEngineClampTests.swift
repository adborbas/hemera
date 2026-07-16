import Testing
import TileGridEngine

/// Tests verifying that tiles wider than the grid are clamped to the column
/// count rather than writing cells out of bounds.
struct TileGridEngineClampTests {

    @Test
    func place_tileWiderThanGrid_clampsWithoutCrashing() {
        /**
         A `.large` tile has spanX 4; a 2-column grid is narrower than that.
         Before clamping, layout wrote grid cells past the row width and trapped.
         */
        let tile = Tile(title: "x", size: .large)
        let engine = TileGridEngine(columns: 2, tiles: [tile])

        // Assert on the cells `place()` actually wrote — not just the span
        // `snapshot()` recomputes — so a wrong-region write is caught too.
        let cells = engine.cells

        // Every row stays within the column count (the OOB write is gone).
        #expect(cells.allSatisfy { $0.count == 2 })

        // `.large` clamps to spanX 2 and keeps spanY 4: a fully reserved 4x2 block.
        #expect(cells.count == 4)
        let ownedCells = cells.flatMap { $0 }.filter { $0.tileID == tile.id }
        #expect(ownedCells.count == 8)
        let originCells = cells.flatMap { $0 }.filter { if case .origin = $0 { return true } else { return false } }
        #expect(originCells.count == 1)

        // And the snapshot reports the matching clamped span.
        let snapshot = engine.snapshot()
        #expect(snapshot.placements.count == 1)
        #expect(snapshot.placements.first?.spanX == 2)
    }

    @Test
    func place_columnsOne_anyTileClamps() {
        // spanX 2 in a single-column grid must clamp to 1.
        let engine = TileGridEngine(
            columns: 1,
            tiles: [Tile(title: "s", size: .small)]
        )

        let snapshot = engine.snapshot()

        #expect(snapshot.placements.count == 1)
        #expect(snapshot.placements.first?.spanX == 1)
    }

    @Test
    func place_tileNarrowerThanGrid_spanUnchanged() {
        /**
         Regression guard for in-app sizing: a `.large` tile (spanX 4) in a
         grid at least 4 wide keeps its full span.
         */
        let engine = TileGridEngine(
            columns: 4,
            tiles: [Tile(title: "l", size: .large)]
        )

        let snapshot = engine.snapshot()

        #expect(snapshot.placements.first?.spanX == 4)
    }
}
