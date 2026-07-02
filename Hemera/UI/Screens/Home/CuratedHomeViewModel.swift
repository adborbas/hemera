import Foundation
import Mortar
import TileGridEngine

@Observable
@MainActor
final class CuratedHomeViewModel {

    private(set) var isRetrying = false
    private(set) var isEditing = false
    private(set) var draftTiles: [Tile]?
    private(set) var undoStack: [EditAction] = []
    private(set) var redoStack: [EditAction] = []
    private(set) var isFirstLoad = true
    var selectedTileID: Tile.ID?

    let isDemoMode: Bool
    let haWebViewPresenter: HAWebViewPresenter
    let viewModelFactory: ViewModelFactory
    let homeTileRepository: any HomeTileRepository

    var syncFailed: Bool {
        errorNotifier?.syncFailed ?? false
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// Captured at `enterEditMode` time so commit can map tile IDs back to
    /// entity IDs without re-querying the live data.
    private var entityIdByTileId: [Tile.ID: String] = [:]

    private let errorNotifier: ErrorNotifier?
    private let connectionRetrier: (any ConnectionRetrying)?
    private var retryTimeoutTask: Task<Void, Never>?
    private var firstLoadTask: Task<Void, Never>?
    private let resync: () async -> Void

    init(
        homeTileRepository: any HomeTileRepository,
        viewModelFactory: ViewModelFactory,
        authManager: any AuthManaging,
        demoCoordinator: any DemoCoordinating,
        errorNotifier: ErrorNotifier? = nil,
        connectionRetrier: (any ConnectionRetrying)? = nil,
        resync: @escaping () async -> Void = { }
    ) {
        self.homeTileRepository = homeTileRepository
        self.viewModelFactory = viewModelFactory
        self.isDemoMode = demoCoordinator.isActive
        self.haWebViewPresenter = HAWebViewPresenter(authManager: authManager)
        self.errorNotifier = errorNotifier
        self.connectionRetrier = connectionRetrier
        self.resync = resync
    }

    func refresh() async {
        await resync()
    }

    // MARK: - Tile Building

    /// Builds the `Tile` array from a `@Query` result. Uses the factory's
    /// session-scoped cache to keep card-VM identity stable across renders.
    func tiles(from homeTiles: [HomeTile]) -> [Tile] {
        homeTiles.map { homeTile in
            Tile(
                id: UUID(stableForString: homeTile.entityId),
                title: viewModelFactory.makeViewModel(forEntityId: homeTile.entityId)?.name ?? homeTile.entityId,
                size: homeTile.tileSize
            )
        }
    }

    /// While editing, `draftTiles` overrides the live query so sync events
    /// don't move tiles under the user's finger.
    func displayedTiles(homeTiles: [HomeTile]) -> [Tile] {
        draftTiles ?? tiles(from: homeTiles)
    }

    // MARK: - Edit Mode

    /// Enters edit mode using the current `@Query` result as the seed.
    func enterEditMode(homeTiles: [HomeTile]) {
        let entries = homeTiles.map { homeTile -> (tile: Tile, entityId: String) in
            let tile = Tile(
                id: UUID(stableForString: homeTile.entityId),
                title: viewModelFactory.makeViewModel(forEntityId: homeTile.entityId)?.name ?? homeTile.entityId,
                size: homeTile.tileSize
            )
            return (tile, homeTile.entityId)
        }
        enterEditMode(seed: entries)
    }

    /// Snapshots a pre-built seed into edit-mode state. Kept for tests; views
    /// should prefer `enterEditMode(homeTiles:)`.
    func enterEditMode(seed entries: [(tile: Tile, entityId: String)]) {
        draftTiles = entries.map(\.tile)
        entityIdByTileId = Dictionary(uniqueKeysWithValues: entries.map { ($0.tile.id, $0.entityId) })
        undoStack = []
        redoStack = []
        selectedTileID = nil
        isEditing = true
    }

    /// Commits the draft layout to storage (if requested) and exits edit
    /// mode. The view re-derives `displayedTiles` from its `@Query` once
    /// `draftTiles` is cleared.
    func exitEditMode(commit: Bool) {
        if commit, let tiles = draftTiles {
            let updates: [(entityId: String, sortOrder: Int, size: TileSize)] = tiles
                .enumerated()
                .compactMap { index, tile in
                    guard let entityId = entityIdByTileId[tile.id] else { return nil }
                    return (entityId: entityId, sortOrder: index, size: tile.size)
                }
            homeTileRepository.commitHomeTileLayout(updates)
        }
        draftTiles = nil
        entityIdByTileId = [:]
        undoStack = []
        redoStack = []
        selectedTileID = nil
        isEditing = false
    }

    /// Drag-reorder updates from the grid; replaces the draft tile order.
    func applyReorder(_ tiles: [Tile]) {
        guard isEditing else { return }
        draftTiles = tiles
    }

    /// Called by the grid before a drag finishes, so undo can restore the
    /// pre-reorder order.
    func recordReorderUndo(previousOrder: [Tile.ID]) {
        undoStack.append(.reorder(previousOrder: previousOrder))
        redoStack = []
    }

    func resizeTile(_ tile: Tile, to targetSize: TileSize) {
        guard isEditing, var tiles = draftTiles,
              let index = tiles.firstIndex(where: { $0.id == tile.id })
        else { return }
        let oldSize = tiles[index].size
        guard oldSize != targetSize else { return }
        undoStack.append(.resize(tileID: tile.id, oldSize: oldSize))
        redoStack = []
        tiles[index].size = targetSize
        draftTiles = tiles
    }

    func performUndo() {
        guard let action = undoStack.popLast(), let inverse = apply(action) else { return }
        redoStack.append(inverse)
    }

    func performRedo() {
        guard let action = redoStack.popLast(), let inverse = apply(action) else { return }
        undoStack.append(inverse)
    }

    /// Applies an edit action to the draft and returns its inverse, so undo
    /// and redo are the same operation walking opposite stacks.
    private func apply(_ action: EditAction) -> EditAction? {
        guard var tiles = draftTiles else { return nil }
        let inverse: EditAction
        switch action {
        case .resize(let tileID, let oldSize):
            guard let index = tiles.firstIndex(where: { $0.id == tileID }) else { return nil }
            inverse = .resize(tileID: tileID, oldSize: tiles[index].size)
            tiles[index].size = oldSize
        case .reorder(let previousOrder):
            inverse = .reorder(previousOrder: tiles.map(\.id))
            let byID = Dictionary(uniqueKeysWithValues: tiles.map { ($0.id, $0) })
            tiles = previousOrder.compactMap { byID[$0] }
        }
        draftTiles = tiles
        return inverse
    }

    // MARK: - First-load Animation

    /// Starts the per-tile stagger window. After it elapses, `isFirstLoad`
    /// flips to false so subsequent updates don't re-trigger the entrance
    /// animation. Calling this multiple times restarts the timer with the
    /// latest tile count.
    func startFirstLoadTimer(tileCount: Int) {
        guard isFirstLoad else { return }
        firstLoadTask?.cancel()
        let timeout = max(1.0, Double(min(tileCount, 15)) * Mortar.Motion.staggerInterval + 0.5)
        firstLoadTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            self?.isFirstLoad = false
        }
    }

    // MARK: - Sync / Retry

    func retrySyncAndReload() {
        isRetrying = true
        connectionRetrier?.retryConnection()
        retryTimeoutTask?.cancel()
        retryTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            isRetrying = false
        }
    }

    // MARK: - Other Actions

    func openEntityInHA(entityId: String, deviceId: String?) {
        haWebViewPresenter.openEntity(entityId, deviceId: deviceId)
    }

    func removeFromHome(entityId: String) {
        homeTileRepository.removeFromHome(entityId: entityId)
    }
}
