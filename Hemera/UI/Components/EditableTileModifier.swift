import SwiftUI
import Mortar
import TileGridEngine

/// Makes a tile inert in edit mode; its badges are drawn by `TileEditBadges`.
struct EditableTileModifier: ViewModifier {
    let tile: Tile
    let isEditing: Bool
    let onTap: () -> Void

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isEditing)
            .environment(\.cardIconsActive, !isEditing)
            .contentShape(Rectangle())
            .onTapGesture {
                // In edit mode the gesture deliberately swallows the tap so it
                // doesn't bubble to the grid's tap-outside-to-exit handler.
                if !isEditing {
                    onTap()
                }
            }
    }
}

/// The remove badge on a tile's top-leading corner curve, the resize badge inside the opposite corner.
struct TileEditBadges: View {
    let tile: Tile
    let onRemove: () -> Void
    let onResize: (TileSize) -> Void

    private static let cornerOffset = Mortar.TapTarget.minimum / 2
    /// Puts the remove badge's centre on the curve of a tile's rounded corner.
    private static let removeInset: CGFloat = 7
    /// The gap between the resize badge and the tile's edges.
    private static let resizeInset: CGFloat = 6
    private static let resizeOffset = (Mortar.TapTarget.minimum - Mortar.IconSize.s) / 2 - resizeInset

    private var nextSize: TileSize {
        tile.size == .small ? .medium : .small
    }

    private var resizeIcon: String {
        tile.size == .small
            ? "arrow.up.left.and.arrow.down.right"
            : "arrow.down.right.and.arrow.up.left"
    }

    var body: some View {
        Color.clear
            .overlay(alignment: .topLeading) {
                EditBadgeButton(Localization.remove, systemImage: "minus", hitDiameter: 32, action: onRemove)
                    .offset(x: -Self.cornerOffset + Self.removeInset, y: -Self.cornerOffset + Self.removeInset)
            }
            .overlay(alignment: .bottomTrailing) {
                EditBadgeButton(
                    tile.size == .small ? Localization.makeLarger : Localization.makeSmaller,
                    systemImage: resizeIcon,
                    hitDiameter: 36
                ) {
                    onResize(nextSize)
                }
                .offset(x: Self.resizeOffset, y: Self.resizeOffset)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(tile.title)
    }
}

extension EnvironmentValues {
    /// Hosts that show tile editing without the wiggle set this to false.
    @Entry var tilesWiggleWhileEditing = true
}

private extension TileEditBadges {
    enum Localization {
        static let remove = String(
            localized: "Remove",
            comment: "Accessibility label for the badge that removes a tile while editing a tile layout"
        )
        static let makeLarger = String(
            localized: "Make Larger",
            comment: "Accessibility label for the tile resize button when tapping it enlarges the tile"
        )
        static let makeSmaller = String(
            localized: "Make Smaller",
            comment: "Accessibility label for the tile resize button when tapping it shrinks the tile"
        )
    }
}

extension View {
    func editableTile(
        _ tile: Tile,
        isEditing: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        modifier(EditableTileModifier(
            tile: tile,
            isEditing: isEditing,
            onTap: onTap
        ))
    }
}
