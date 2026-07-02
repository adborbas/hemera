import SwiftData
import SwiftUI
import Mortar
import TileGridEngine

struct CuratedHomeView: View {
    @Bindable var viewModel: CuratedHomeViewModel
    @Namespace private var overlayTransition

    @Query(sort: \HomeTile.sortOrder) private var homeTiles: [HomeTile]

    @State private var overlayItem: OverlayItem?

    private var displayedTiles: [Tile] {
        viewModel.displayedTiles(homeTiles: homeTiles)
    }

    /// `Tile.id` is a SHA-derived `UUID(stableForString:)`. Precompute the
    /// reverse map once per body eval so `tileView(for:)` is O(1) instead of
    /// O(n) per tile (which compounded into O(n²) on dense home grids).
    private var entityIdByTileId: [Tile.ID: String] {
        Dictionary(uniqueKeysWithValues: homeTiles.map { homeTile in
            (UUID(stableForString: homeTile.entityId), homeTile.entityId)
        })
    }

    private var sections: [TileSection] {
        [TileSection(tiles: displayedTiles)]
    }

    private var isEmpty: Bool {
        homeTiles.isEmpty
    }

    private var sectionsBinding: Binding<[TileSection]> {
        Binding(
            get: { sections },
            set: { newValue in
                viewModel.applyReorder(newValue.first?.tiles ?? [])
            }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isRetrying {
                    ProgressView()
                        .controlSize(.large)
                } else if viewModel.syncFailed, isEmpty {
                    SyncErrorView {
                        viewModel.retrySyncAndReload()
                    }
                } else if isEmpty {
                    HomeEmptyView()
                } else {
                    TiledGrid(
                        sections: sectionsBinding,
                        isEditing: Binding(
                            get: { viewModel.isEditing },
                            set: { _ in /* edit-mode is driven by VM actions */ }
                        ),
                        onReorder: { previousOrder in
                            viewModel.recordReorderUndo(previousOrder: previousOrder)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    ) { tile in
                        tileView(for: tile)
                    }
                    .onTapGesture {
                        if viewModel.isEditing {
                            withAnimation {
                                viewModel.exitEditMode(commit: true)
                            }
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle(Localization.home)
            .toolbar {
                if viewModel.isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(Localization.cancel) {
                            withAnimation {
                                viewModel.exitEditMode(commit: false)
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                viewModel.performUndo()
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Label(Localization.undo, systemImage: "arrow.uturn.backward")
                                .labelStyle(.iconOnly)
                        }
                        .disabled(!viewModel.canUndo)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(Localization.done) {
                            withAnimation {
                                viewModel.exitEditMode(commit: true)
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(item: $overlayItem) { item in
                item.viewModel.makeOverlayView(isPresented: $overlayItem.isPresented)
                    .applyUnlessScreenshotMode {
                        $0.navigationTransition(.zoom(sourceID: item.id, in: overlayTransition))
                    }
            }
            .haWebViewCover(presenter: viewModel.haWebViewPresenter)
        }
        .task {
            viewModel.startFirstLoadTimer(tileCount: homeTiles.count)
        }
        .onDisappear {
            // Leaving the tab mid-edit would otherwise strand the draft;
            // commit, matching the tap-outside-to-exit behavior.
            if viewModel.isEditing {
                viewModel.exitEditMode(commit: true)
            }
        }
    }
}

// MARK: - Tile View

private extension CuratedHomeView {

    @ViewBuilder
    func tileView(for tile: Tile) -> some View {
        if let entityId = entityIdByTileId[tile.id],
           let vm = viewModel.viewModelFactory.makeViewModel(forEntityId: entityId) {
            let tileIndex = displayedTiles.firstIndex(where: { $0.id == tile.id }) ?? 0
            let card = vm.makeCardView()
                .matchedTransitionSource(id: vm.id, in: overlayTransition)
                .tileEntrance(index: tileIndex, isActive: viewModel.isFirstLoad)
                .environment(\.isMediumTile, tile.size == .medium)
                .editableTile(
                    tile,
                    isEditing: viewModel.isEditing,
                    selectedTileID: $viewModel.selectedTileID,
                    onResize: { targetSize in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            viewModel.resizeTile(tile, to: targetSize)
                        }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    },
                    onTap: {
                        if let target = viewModel.viewModelFactory.handleCardTap(entityId: entityId) {
                            overlayItem = OverlayItem(id: target.id, viewModel: target)
                        }
                    }
                )

            // Detached (not emptied) while editing so its long-press
            // recognizer doesn't compete with the reorder drag.
            if viewModel.isEditing {
                card
            } else {
                card.contextMenu {
                    Button {
                        withAnimation {
                            viewModel.enterEditMode(homeTiles: homeTiles)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(Localization.editLayout, systemImage: "square.and.pencil")
                    }
                    if !viewModel.isDemoMode {
                        Button {
                            viewModel.openEntityInHA(entityId: vm.id, deviceId: vm.deviceId)
                        } label: {
                            Label(Localization.openInHomeAssistant, systemImage: "globe")
                        }
                    }
                    Button(role: .destructive) {
                        viewModel.removeFromHome(entityId: vm.id)
                    } label: {
                        Label(Localization.removeFromHome, systemImage: "minus.circle")
                    }
                }
            }
        } else {
            EntityCard {
                Text(tile.title)
            }
        }
    }
}

private extension CuratedHomeView {
    enum Localization {
        static let home = String(localized: "Home", comment: "Navigation title for the Home screen showing pinned entities")
        static let cancel = String(localized: "Cancel", comment: "Button to cancel layout editing and discard changes")
        static let done = String(localized: "Done", comment: "Button to commit layout edits and leave edit mode on the Home screen")
        static let undo = String(localized: "Undo", comment: "Toolbar button to undo the last layout edit")
        static let editLayout = String(localized: "Edit Layout", comment: "Context menu action to enter tile layout editing mode")
        static let removeFromHome = String(localized: "Remove from Home", comment: "Context menu action to unpin an entity from the Home screen")
        static let openInHomeAssistant = String(localized: "Open in Home Assistant", comment: "Context menu action to open an entity in the Home Assistant web interface")
    }
}
