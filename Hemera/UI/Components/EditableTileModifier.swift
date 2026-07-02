import SwiftUI
import Mortar
import TileGridEngine

/// Combines wiggle animation and a resize button for tiles in edit mode.
///
/// Mimics Apple's Home app: in edit mode, tiles wiggle and a small circular
/// resize button appears in the bottom-trailing corner of every tile.
/// Tapping it toggles the tile size between small and medium.
struct EditableTileModifier: ViewModifier {
    let tile: Tile
    let isEditing: Bool
    let onResize: (TileSize) -> Void
    let onTap: () -> Void

    private var nextSize: TileSize {
        tile.size == .small ? .medium : .small
    }

    private var resizeIcon: String {
        tile.size == .small
            ? "arrow.up.left.and.arrow.down.right"
            : "arrow.down.right.and.arrow.up.left"
    }

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isEditing)
            .overlay(alignment: .bottomTrailing) {
                if isEditing {
                    resizeButton
                }
            }
            .wiggle(isWiggling: isEditing, seed: tile.id.hashValue)
            .contentShape(Rectangle())
            .onTapGesture {
                // In edit mode the gesture deliberately swallows the tap so it
                // doesn't bubble to the grid's tap-outside-to-exit handler.
                if !isEditing {
                    onTap()
                }
            }
    }

    // MARK: - Resize Button

    private var resizeButton: some View {
        Button {
            onResize(nextSize)
        } label: {
            Label(
                tile.size == .small ? Localization.makeLarger : Localization.makeSmaller,
                systemImage: resizeIcon
            )
            .labelStyle(.iconOnly)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: Mortar.IconSize.s, height: Mortar.IconSize.s)
            .background(
                Circle()
                    .fill(.thinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            // Minimum tap target (HIG) around the smaller visible circle.
            .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}

private extension EditableTileModifier {
    enum Localization {
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
        onResize: @escaping (TileSize) -> Void,
        onTap: @escaping () -> Void
    ) -> some View {
        modifier(EditableTileModifier(
            tile: tile,
            isEditing: isEditing,
            onResize: onResize,
            onTap: onTap
        ))
    }
}
