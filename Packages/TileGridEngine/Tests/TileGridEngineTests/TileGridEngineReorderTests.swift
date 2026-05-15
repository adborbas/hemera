import Testing
import TileGridEngine

/// Tests for core slide/shift reordering behavior.
///
/// These tests verify the fundamental reordering mechanics regardless of tile size.
/// When a tile is dragged over a target, it slides to that position and other tiles shift.
struct TileGridEngineReorderTests {

    // MARK: - Adjacent moves

    @Test
    func moveLeft_adjacentTiles() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s"], columns: 6)

        scenario.beginDragging("C")
        scenario.hover(over: "B")
        scenario.expectOrder(["A", "C", "B"])
        scenario.endDrag()
        scenario.expectOrder(["A", "C", "B"])
    }

    @Test
    func moveRight_adjacentTiles() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s"], columns: 6)

        scenario.beginDragging("A")
        scenario.hover(over: "B")
        scenario.expectOrder(["B", "A", "C"])
        scenario.endDrag()
        scenario.expectOrder(["B", "A", "C"])
    }

    // MARK: - Multi-step moves

    @Test
    func moveForward_multiplePositions() {
        // A moves from first to last position
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s"], columns: 6)

        scenario.beginDragging("A")
        scenario.hover(over: "B")
        scenario.expectOrder(["B", "A", "C"])

        scenario.hover(over: "C")
        scenario.expectOrder(["B", "C", "A"])
        scenario.endDrag()
        scenario.expectOrder(["B", "C", "A"])
    }

    @Test
    func moveBackward_multiplePositions() {
        // D moves from last to first position
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s", "D:s"], columns: 8)

        scenario.beginDragging("D")
        scenario.hover(over: "C")
        scenario.expectOrder(["A", "B", "D", "C"])

        scenario.hover(over: "B")
        scenario.expectOrder(["A", "D", "B", "C"])

        scenario.hover(over: "A")
        scenario.expectOrder(["D", "A", "B", "C"])
        scenario.endDrag()
        scenario.expectOrder(["D", "A", "B", "C"])
    }

    @Test
    func moveToFirst() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s", "D:s"], columns: 8)

        scenario.beginDragging("C")
        scenario.hover(over: "B")
        scenario.expectOrder(["A", "C", "B", "D"])

        scenario.hover(over: "A")
        scenario.expectOrder(["C", "A", "B", "D"])
        scenario.endDrag()
        scenario.expectOrder(["C", "A", "B", "D"])
    }

    @Test
    func moveToLast() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s", "D:s"], columns: 8)

        scenario.beginDragging("B")
        scenario.hover(over: "C")
        scenario.expectOrder(["A", "C", "B", "D"])

        scenario.hover(over: "D")
        scenario.expectOrder(["A", "C", "D", "B"])
        scenario.endDrag()
        scenario.expectOrder(["A", "C", "D", "B"])
    }

    // MARK: - Chained moves

    @Test
    func chainedMoves_throughMultipleTargets() {
        let scenario = TileGridEngineTestScenario(["A:s", "B:s", "C:s", "D:s"], columns: 8)

        scenario.beginDragging("B")
        scenario.hover(over: "C")
        scenario.expectOrder(["A", "C", "B", "D"])

        scenario.hover(over: "D")
        scenario.expectOrder(["A", "C", "D", "B"])
        scenario.endDrag()
        scenario.expectOrder(["A", "C", "D", "B"])
    }

    // MARK: - Cross-row movements

    @Test
    func moveUp_acrossRows() {
        // Grid layout: [A, B], [C, D]
        // Drag C up to A's position
        let scenario = TileGridEngineTestScenario.grid(
            columns: 4,
            rows: [
                [.small("A"), .small("B")],
                [.small("C"), .small("D")]
            ]
        )

        scenario.beginDragging("C")
        scenario.hover(over: "A")
        // Order: A, B, C, D → C, A, B, D
        // Layout: [C, A], [B, D]
        scenario.expectGridCells([
            [.small("C"), .small("A")],
            [.small("B"), .small("D")]
        ])
        scenario.endDrag()
    }

    @Test
    func moveDown_acrossRows() {
        // Grid layout: [A, B], [C, D]
        // Drag B down to D's position
        let scenario = TileGridEngineTestScenario.grid(
            columns: 4,
            rows: [
                [.small("A"), .small("B")],
                [.small("C"), .small("D")]
            ]
        )

        scenario.beginDragging("B")
        scenario.hover(over: "D")
        // Order: A, B, C, D → A, C, D, B
        // Layout: [A, C], [D, B]
        scenario.expectGridCells([
            [.small("A"), .small("C")],
            [.small("D"), .small("B")]
        ])
        scenario.endDrag()
    }

    @Test
    func moveAcrossMultipleRows() {
        let scenario = TileGridEngineTestScenario.grid(
            columns: 2,
            rows: [
                [.small("A")],
                [.small("B")],
                [.small("C")]
            ]
        )

        scenario.beginDragging("A")
        scenario.hover(over: "B")
        scenario.expectGridCells([
            [.small("B")],
            [.small("A")],
            [.small("C")]
        ])

        scenario.hover(over: "C")
        scenario.expectGridCells([
            [.small("B")],
            [.small("C")],
            [.small("A")]
        ])
        scenario.endDrag()
    }

    @Test
    func moveWithinRow_multiColumn() {
        let scenario = TileGridEngineTestScenario.grid(
            columns: 6,
            rows: [
                [.small("A"), .small("B"), .small("C")],
                [.small("D"), .small("E"), .small("F")]
            ]
        )

        scenario.beginDragging("A")
        scenario.hover(over: "B")
        scenario.expectGridCells([
            [.small("B"), .small("A"), .small("C")],
            [.small("D"), .small("E"), .small("F")]
        ])

        scenario.hover(over: "C")
        scenario.expectGridCells([
            [.small("B"), .small("C"), .small("A")],
            [.small("D"), .small("E"), .small("F")]
        ])
        scenario.endDrag()
    }
}
