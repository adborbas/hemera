import Mortar
import SwiftUI
import TileGridEngine

/// An entity feed in the Home tile grid; cards behave as they do on area pages.
struct EntityFeedView: View {
    let viewModel: EntityFeedViewModel

    @Namespace private var overlayTransition
    @State private var overlayItem: OverlayItem?

    var body: some View {
        let entityIds = viewModel.entityIdByTileId

        TiledGrid(sections: .constant(viewModel.sections), isEditing: .constant(false)) { tile in
            card(for: tile, entityId: entityIds[tile.id])
        }
        .sheet(item: $overlayItem) { item in
            item.viewModel.makeOverlayView(isPresented: $overlayItem.isPresented)
                .applyUnlessScreenshotMode {
                    $0.navigationTransition(.zoom(sourceID: item.id, in: overlayTransition))
                }
        }
        .haWebViewCover(presenter: viewModel.haWebViewPresenter)
    }

    @ViewBuilder
    private func card(for tile: Tile, entityId: String?) -> some View {
        if let entityId, let vm = viewModel.viewModelFactory.makeViewModel(forLiveEntityId: entityId) {
            vm.makeCardView()
                .environment(\.isMediumTile, tile.size == .medium)
                .matchedTransitionSource(id: vm.id, in: overlayTransition)
                .onTapGesture {
                    if let target = viewModel.viewModelFactory.handleCardTap(entityId: vm.id) {
                        overlayItem = OverlayItem(id: target.id, viewModel: target)
                    }
                }
                .contextMenu {
                    EntityCardContextMenu(
                        isOnHome: viewModel.isOnHome(entityId: vm.id),
                        isDemoMode: viewModel.isDemoMode,
                        addToHome: { viewModel.addToHome(entityId: vm.id) },
                        openInHomeAssistant: { viewModel.openEntityInHA(entityId: vm.id, deviceId: vm.deviceId) }
                    )
                }
        }
    }
}
