import Mortar
import SwiftData
import SwiftUI
import TileGridEngine

/// The Theme step's content: the Home as arranged, inert, under the theme editor.
struct OnboardingThemeStep: View {

    let home: CuratedHomeViewModel
    /// Changes on Reset, so the editor starts over on None.
    let resetCount: Int

    @Query(sort: \HomeTile.sortOrder) private var homeTiles: [HomeTile]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var entityIdByTileId: [Tile.ID: String] {
        Dictionary(uniqueKeysWithValues: homeTiles.map { (UUID(stableForString: $0.entityId), $0.entityId) })
    }

    var body: some View {
        TiledGrid(
            sections: .constant([TileSection(tiles: home.displayedTiles(homeTiles: homeTiles))]),
            isEditing: .constant(false)
        ) { tile in
            tileView(for: tile)
        }
        // The same placement as the main app's editor, above the bottom button.
        .overlay(alignment: horizontalSizeClass == .compact ? .bottom : .bottomTrailing) {
            let isCompact = horizontalSizeClass == .compact
            Editor(isDrawer: isCompact)
                .frame(width: isCompact ? nil : 360)
                .fixedSize(horizontal: false, vertical: true)
                .padding(isCompact ? 0 : Mortar.Spacing.xl)
                .id(resetCount)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboardingThemeStep")
    }

    @ViewBuilder
    private func tileView(for tile: Tile) -> some View {
        if let entityId = entityIdByTileId[tile.id], let card = home.viewModelFactory.makeViewModel(forEntityId: entityId) {
            card.makeCardView()
                .environment(\.isMediumTile, tile.size == .medium)
                .allowsHitTesting(false)
        }
    }
}

/// Reads the theme here, so a colour change doesn't rebuild the grid.
private struct Editor: View {
    let isDrawer: Bool

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ThemeEditorView(theme: themeManager.theme, isDrawer: isDrawer, showsActions: false)
    }
}
