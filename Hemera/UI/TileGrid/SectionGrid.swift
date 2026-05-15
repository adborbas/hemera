import SwiftUI
import TileGridEngine

/// Renders a single section of tiles using TileGridEngine for reordering.
struct SectionGrid<Content: View>: View {

    @Binding var tiles: [Tile]
    let columns: Int
    let containerWidth: CGFloat
    @Binding var isEditing: Bool
    var onReorder: (([Tile.ID]) -> Void)?
    let content: (Tile) -> Content

    @State private var engine: TileGridEngine?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartCenter: CGPoint?
    @State private var hitTestPlacements: [TileGridEngine.Placement]?
    @State private var lastHoverTargetID: Tile.ID?

    var body: some View {
        let currentEngine = engine ?? TileGridEngine(columns: columns, tiles: tiles)
        let snapshot = currentEngine.snapshot()
        let metrics = GridMetrics(
            columns: columns,
            containerWidth: containerWidth,
            rowCount: snapshot.rowCount
        )

        ZStack(alignment: .topLeading) {
            ghostPlaceholder(engine: currentEngine, snapshot: snapshot, metrics: metrics)
            tilesView(engine: currentEngine, snapshot: snapshot, metrics: metrics)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: metrics.contentHeight,
            maxHeight: metrics.contentHeight,
            alignment: .topLeading
        )
        .onChange(of: tiles) { _, newTiles in
            if engine?.draggingID == nil {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    engine = TileGridEngine(columns: columns, tiles: newTiles)
                }
            }
        }
        .onChange(of: columns) { _, newColumns in
            engine = TileGridEngine(columns: newColumns, tiles: tiles)
        }
        .onAppear {
            engine = TileGridEngine(columns: columns, tiles: tiles)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func ghostPlaceholder(
        engine: TileGridEngine,
        snapshot: TileGridEngine.Snapshot,
        metrics: GridMetrics
    ) -> some View {
        if let draggingID = snapshot.draggingID,
           let placement = snapshot.placements.first(where: { $0.id == draggingID }),
           let tile = engine.tilesByID[draggingID] {
            let origin = metrics.origin(for: placement)
            let size = metrics.size(for: placement)
            content(tile)
                .frame(width: size.width, height: size.height)
                .offset(x: origin.x, y: origin.y)
                .opacity(0.25)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func tilesView(
        engine: TileGridEngine,
        snapshot: TileGridEngine.Snapshot,
        metrics: GridMetrics
    ) -> some View {
        ForEach(snapshot.placements, id: \.id) { placement in
            tileView(
                placement: placement,
                engine: engine,
                snapshot: snapshot,
                metrics: metrics
            )
        }
    }

    @ViewBuilder
    private func tileView(
        placement: TileGridEngine.Placement,
        engine: TileGridEngine,
        snapshot: TileGridEngine.Snapshot,
        metrics: GridMetrics
    ) -> some View {
        if let tile = engine.tilesByID[placement.id] {
            let origin = metrics.origin(for: placement)
            let size = metrics.size(for: placement)
            let isDragging = snapshot.draggingID == placement.id
            let visualOrigin = computeVisualOrigin(
                origin: origin,
                size: size,
                isDragging: isDragging
            )

            content(tile)
                .frame(width: size.width, height: size.height)
                .offset(x: visualOrigin.x, y: visualOrigin.y)
                .scaleEffect(isDragging ? 1.03 : 1.0)
                .shadow(radius: isDragging ? 8 : 0)
                .zIndex(isDragging ? 1 : 0)
                .highPriorityGesture(dragGesture(for: placement.id, metrics: metrics))
                .allowsHitTesting(snapshot.draggingID == nil || isDragging)
        }
    }

    private func computeVisualOrigin(
        origin: CGPoint,
        size: CGSize,
        isDragging: Bool
    ) -> CGPoint {
        if isDragging, let dragStartCenter {
            let centerX = dragStartCenter.x + dragOffset.width
            let centerY = dragStartCenter.y + dragOffset.height
            return CGPoint(x: centerX - size.width / 2, y: centerY - size.height / 2)
        }
        return origin
    }

    // MARK: - Drag Handling

    private func dragGesture(for tileID: Tile.ID, metrics: GridMetrics) -> some Gesture {
        DragGesture(minimumDistance: isEditing ? 10 : .infinity)
            .onChanged { value in
                guard isEditing else { return }
                if engine?.draggingID == nil {
                    // Begin drag - capture original placements for hit-testing
                    let snapshot = engine?.snapshot()
                    hitTestPlacements = snapshot?.placements
                    engine?.beginDrag(tileID: tileID)

                    // Compute initial center for the dragged tile
                    if let placement = snapshot?.placements.first(where: { $0.id == tileID }) {
                        let origin = metrics.origin(for: placement)
                        let size = metrics.size(for: placement)
                        dragStartCenter = CGPoint(
                            x: origin.x + size.width / 2,
                            y: origin.y + size.height / 2
                        )
                    }
                }

                dragOffset = value.translation

                // Find which tile we're hovering over
                if let dragStartCenter {
                    let dragCenter = CGPoint(
                        x: dragStartCenter.x + value.translation.width,
                        y: dragStartCenter.y + value.translation.height
                    )

                    let targetID = findTileAt(point: dragCenter, excluding: tileID, metrics: metrics)

                    // Only call hover when target actually changes
                    if targetID != lastHoverTargetID {
                        lastHoverTargetID = targetID
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            engine?.hover(over: targetID)
                        }

                        // Update hit-test positions to match new layout
                        if let newSnapshot = engine?.snapshot() {
                            hitTestPlacements = newSnapshot.placements
                        }
                    }
                }
            }
            .onEnded { _ in
                guard isEditing else { return }

                // Capture pre-reorder order for undo
                let previousOrder = tiles.map(\.id)

                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    // Commit the reorder
                    engine?.endDrag(commit: true)

                    // Sync back to binding
                    if let newTiles = engine?.tiles {
                        let reordered = newTiles.map(\.id) != previousOrder
                        tiles = newTiles
                        if reordered {
                            onReorder?(previousOrder)
                        }
                    }
                }

                dragOffset = .zero
                dragStartCenter = nil
                hitTestPlacements = nil
                lastHoverTargetID = nil
            }
    }

    /// Find which tile (if any) is at the given point.
    /// Uses original positions captured at drag start to avoid flickering.
    private func findTileAt(point: CGPoint, excluding: Tile.ID, metrics: GridMetrics) -> Tile.ID? {
        guard let placements = hitTestPlacements else { return nil }

        for placement in placements {
            if placement.id == excluding { continue }

            let origin = metrics.origin(for: placement)
            let size = metrics.size(for: placement)
            let rect = CGRect(origin: origin, size: size)

            if rect.contains(point) {
                return placement.id
            }
        }

        return nil
    }
}

// MARK: - Grid Metrics

/// Layout calculations for the tile grid.
struct GridMetrics {
    let columns: Int
    let containerWidth: CGFloat
    let rowCount: Int

    let spacingX: CGFloat
    let spacingY: CGFloat
    let padding: CGFloat

    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let contentHeight: CGFloat

    init(columns: Int, containerWidth: CGFloat, rowCount: Int) {
        self.columns = columns
        self.containerWidth = containerWidth
        self.rowCount = rowCount

        self.spacingX = TileGridConstants.columnSpacing
        self.spacingY = TileGridConstants.rowSpacing
        self.padding = TileGridConstants.padding

        let contentWidth = containerWidth - padding * 2
        let totalHorizontalSpacing = spacingX * CGFloat(max(columns - 1, 0))
        let usableWidth = max(contentWidth - totalHorizontalSpacing, 0)
        self.columnWidth = columns > 0 ? usableWidth / CGFloat(columns) : 0

        self.rowHeight = TileGridConstants.smallTileHeight

        self.contentHeight =
            padding * 2 +
            CGFloat(rowCount) * rowHeight +
            spacingY * CGFloat(max(rowCount - 1, 0))
    }

    func origin(for placement: TileGridEngine.Placement) -> CGPoint {
        let x = padding + CGFloat(placement.column) * (columnWidth + spacingX)
        let y = padding + CGFloat(placement.row) * (rowHeight + spacingY)
        return CGPoint(x: x, y: y)
    }

    func size(for placement: TileGridEngine.Placement) -> CGSize {
        let width = columnWidth * CGFloat(placement.spanX)
            + spacingX * CGFloat(placement.spanX - 1)
        let height = rowHeight * CGFloat(placement.spanY)
            + spacingY * CGFloat(max(placement.spanY - 1, 0))
        return CGSize(width: width, height: height)
    }
}

#if DEBUG
// MARK: - Preview

private struct SectionGrid_PreviewWrapper: View {
    @State private var tiles: [Tile] = [
        Tile(title: "Small 1", size: .small),
        Tile(title: "Small 2", size: .small),
        Tile(title: "Medium 1", size: .medium),
        Tile(title: "Large 1", size: .large),
        Tile(title: "Small 3", size: .small),
        Tile(title: "Small 4", size: .small)
    ]
    @State private var isEditing = true

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                SectionGrid(
                    tiles: $tiles,
                    columns: 4,
                    containerWidth: proxy.size.width,
                    isEditing: $isEditing
                ) { tile in
                    PreviewTileView(tile: tile)
                }
            }
        }
    }
}

private struct PreviewTileView: View {
    let tile: Tile

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundColor)

            Text(tile.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.primary)
                .padding(8)
        }
    }

    private var backgroundColor: Color {
        switch tile.size {
        case .small: Color.blue.opacity(0.2)
        case .medium: Color.green.opacity(0.2)
        case .large: Color.orange.opacity(0.2)
        }
    }
}

#Preview {
    SectionGrid_PreviewWrapper()
}
#endif
