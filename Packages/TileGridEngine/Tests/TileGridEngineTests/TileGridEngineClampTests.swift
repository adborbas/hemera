import Testing
import TileGridEngine

/// Tests verifying that tiles wider than the grid are clamped to the column
/// count rather than writing cells out of bounds.
struct TileGridEngineClampTests {

    @Test
    func place_tileWiderThanGrid_clampsWithoutCrashing() {
        // A `.large` tile has spanX 4; a 2-column grid is narrower than that.
        // Before clamping, layout wrote grid cells past the row width and trapped.
        let engine = TileGridEngine(
            columns: 2,
            tiles: [Tile(title: "x", size: .large)]
        )

        let snapshot = engine.snapshot()

        // Laid out without a trap and reports the clamped span.
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
        // Regression guard for in-app sizing: a `.large` tile (spanX 4) in a
        // grid at least 4 wide keeps its full span.
        let engine = TileGridEngine(
            columns: 4,
            tiles: [Tile(title: "l", size: .large)]
        )

        let snapshot = engine.snapshot()

        #expect(snapshot.placements.first?.spanX == 4)
    }
}
