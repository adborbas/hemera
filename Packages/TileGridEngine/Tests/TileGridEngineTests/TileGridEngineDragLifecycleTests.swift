import Testing
import TileGridEngine

/// Tests for drag lifecycle edge cases and state management.
///
/// These tests verify that the engine handles edge cases gracefully and
/// maintains consistent state across drag operations.
struct TileGridEngineDragLifecycleTests {

    // MARK: - Invalid operations

    @Test
    func beginDrag_nonExistingTile_doesNothing() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s"], columns: 4)

        scenario.beginDragging("Z")  // Non-existing
        scenario.hover(over: "A")
        scenario.endDrag()

        scenario.expectOrder(["A", "B"])
        #expect(scenario.draggingID == nil)
    }

    @Test
    func hover_nil_doesNothing() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s"], columns: 4)

        scenario.beginDragging("A")
        scenario.hover(over: nil)
        scenario.endDrag()

        scenario.expectOrder(["A", "B"])
    }

    @Test
    func hover_sameTile_doesNothing() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s"], columns: 4)

        scenario.beginDragging("A")
        scenario.hover(over: "A")
        scenario.endDrag()

        scenario.expectOrder(["A", "B"])
    }

    @Test
    func endDrag_withoutBegin_doesNothing() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s"], columns: 4)

        scenario.endDrag()

        scenario.expectOrder(["A", "B"])
    }

    // MARK: - Cancel (commit: false)

    @Test
    func cancel_revertsToOriginalOrder() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s"], columns: 6)

        scenario.beginDragging("B")
        scenario.hover(over: "C")
        scenario.expectOrder(["A", "C", "B"])

        scenario.endDrag(commit: false)
        scenario.expectOrder(["A", "B", "C"])
    }

    @Test
    func cancel_thenNewDrag_usesOriginalOrder() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s"], columns: 6)

        // First drag, then cancel
        scenario.beginDragging("B")
        scenario.hover(over: "C")
        scenario.expectOrder(["A", "C", "B"])
        scenario.endDrag(commit: false)
        scenario.expectOrder(["A", "B", "C"])

        // New drag should start from original order
        scenario.beginDragging("C")
        scenario.hover(over: "A")
        scenario.expectOrder(["C", "A", "B"])
        scenario.endDrag()
        scenario.expectOrder(["C", "A", "B"])
    }

    // MARK: - Sequential drags

    @Test
    func sequentialDrags_eachStartsFromCommittedOrder() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s"], columns: 6)

        // First drag: A → B
        scenario.beginDragging("A")
        scenario.hover(over: "B")
        scenario.expectOrder(["B", "A", "C"])
        scenario.endDrag()

        // Second drag uses committed order [B, A, C]
        scenario.beginDragging("B")
        scenario.hover(over: "A")
        scenario.expectOrder(["A", "B", "C"])
        scenario.endDrag()
        scenario.expectOrder(["A", "B", "C"])
    }

    // MARK: - Toggle semantics

    @Test
    func hoverSameTargetTwice_revertsToOriginal() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s"], columns: 6)

        scenario.beginDragging("A")
        scenario.hover(over: "B")
        scenario.expectOrder(["B", "A", "C"])

        // Hover B again - should revert
        scenario.hover(over: "B")
        scenario.expectOrder(["A", "B", "C"])
        scenario.endDrag()
        scenario.expectOrder(["A", "B", "C"])
    }

    @Test
    func toggleAfterChainedMoves_revertsToOriginal() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s", "D:s"], columns: 8)

        scenario.beginDragging("A")
        scenario.hover(over: "B")
        scenario.expectOrder(["B", "A", "C", "D"])

        scenario.hover(over: "C")
        scenario.expectOrder(["B", "C", "A", "D"])

        // Toggle C - reverts to ORIGINAL order (not previous working order)
        scenario.hover(over: "C")
        scenario.expectOrder(["A", "B", "C", "D"])
        scenario.endDrag()
        scenario.expectOrder(["A", "B", "C", "D"])
    }
}
