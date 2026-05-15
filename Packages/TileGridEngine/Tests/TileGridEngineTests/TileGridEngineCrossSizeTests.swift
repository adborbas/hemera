import Testing
import TileGridEngine

/// Tests verifying that tiles of different sizes can interact freely.
///
/// With iOS-style slide/shift, there are no size restrictions. Any tile can
/// be dragged to any position. The layout algorithm handles placement naturally.
struct TileGridEngineCrossSizeTests {

    // MARK: - Small ↔ Medium

    @Test
    func small_canMoveToMediumPosition() {
        let scenario = TileGridEngineTestScenario(["S1:s", "S2:s", "M1:m", "S3:s"], columns: 12)

        scenario.beginDragging("S1")
        scenario.hover(over: "M1")
        scenario.expectOrder(["S2", "M1", "S1", "S3"])
        scenario.endDrag()
        scenario.expectOrder(["S2", "M1", "S1", "S3"])
    }

    @Test
    func medium_canMoveToSmallPosition() {
        let scenario = TileGridEngineTestScenario(["M1:m", "S1:s", "S2:s", "M2:m"], columns: 12)

        scenario.beginDragging("M1")
        scenario.hover(over: "S2")
        scenario.expectOrder(["S1", "S2", "M1", "M2"])
        scenario.endDrag()
        scenario.expectOrder(["S1", "S2", "M1", "M2"])
    }

    // MARK: - Medium ↔ Medium

    @Test
    func medium_canMoveToAnotherMediumPosition() {
        let scenario = TileGridEngineTestScenario(["S1:s", "M1:m", "S2:s", "M2:m"], columns: 12)

        scenario.beginDragging("M1")
        scenario.hover(over: "M2")
        scenario.expectOrder(["S1", "S2", "M2", "M1"])
        scenario.endDrag()
        scenario.expectOrder(["S1", "S2", "M2", "M1"])
    }

    // MARK: - Large interactions

    @Test
    func large_canMoveToAnyPosition() {
        let scenario = TileGridEngineTestScenario(["L1:l", "S1:s", "L2:l", "S2:s"], columns: 12)

        // Large to large
        scenario.beginDragging("L1")
        scenario.hover(over: "L2")
        scenario.expectOrder(["S1", "L2", "L1", "S2"])
        scenario.endDrag()

        // Large to small (order is now: S1, L2, L1, S2)
        scenario.beginDragging("L1")
        scenario.hover(over: "S1")
        scenario.expectOrder(["L1", "S1", "L2", "S2"])
        scenario.endDrag()
    }

    // MARK: - Chained cross-size moves

    @Test
    func chainedMoves_acrossDifferentSizes() {
        let scenario = TileGridEngineTestScenario(["M1:m", "L1:l", "M2:m", "L2:l"], columns: 12)

        scenario.beginDragging("M1")
        scenario.hover(over: "L1")
        scenario.expectOrder(["L1", "M1", "M2", "L2"])

        scenario.hover(over: "M2")
        scenario.expectOrder(["L1", "M2", "M1", "L2"])
        scenario.endDrag()
    }

    @Test
    func large_movesThroughMediums() {
        let scenario = TileGridEngineTestScenario(["M1:m", "L1:l", "M2:m", "L2:l"], columns: 12)

        scenario.beginDragging("L1")
        scenario.hover(over: "M2")
        scenario.expectOrder(["M1", "M2", "L1", "L2"])

        scenario.hover(over: "L2")
        scenario.expectOrder(["M1", "M2", "L2", "L1"])
        scenario.endDrag()
    }

    // MARK: - Layout adaptation

    @Test
    func layout_adaptsToNewOrder() {
        // Narrow grid forces wrapping
        let scenario = TileGridEngineTestScenario(["M1:m", "S1:s", "S2:s"], columns: 4)

        scenario.beginDragging("M1")
        scenario.hover(over: "S1")
        scenario.expectOrder(["S1", "M1", "S2"])
        scenario.endDrag()
    }

    @Test
    func small_movedPastMedium_layoutAdapts() {
        let scenario = TileGridEngineTestScenario(["S1:s", "M1:m", "S2:s"], columns: 4)

        scenario.beginDragging("S1")
        scenario.hover(over: "M1")
        scenario.expectOrder(["M1", "S1", "S2"])

        scenario.hover(over: "S2")
        scenario.expectOrder(["M1", "S2", "S1"])
        scenario.endDrag()
    }

    @Test
    func gridLayout_reorderPreservesIntegrity() {
        let scenario = TileGridEngineTestScenario.grid(
            columns: 6,
            rows: [
                [.small("S1"), .medium("M1"), .gap],
                [.small("S2"), .span(of: "M1"), .small("S3")]
            ]
        )

        scenario.beginDragging("M1")
        scenario.hover(over: "S1")
        scenario.expectOrder(["M1", "S1", "S2", "S3"])
        scenario.endDrag()
    }
}
