import SwiftUI
import Mortar
import TileGridEngine

/// Combines wiggle animation and a resize button for tiles in edit mode.
///
/// Mimics Apple's Home app: in edit mode, tiles wiggle and a small circular
/// resize button appears in the bottom-trailing corner. Tapping it toggles
/// the tile size between small and medium.
struct EditableTileModifier: ViewModifier {
    let tile: Tile
    let isEditing: Bool
    @Binding var selectedTileID: Tile.ID?
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

    private var isSelected: Bool {
        selectedTileID == tile.id
    }

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isEditing)
            .overlay(alignment: .bottomTrailing) {
                if isEditing && isSelected {
                    resizeButton
                }
            }
            .wiggle(isWiggling: isEditing, seed: tile.id.hashValue)
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditing {
                    withAnimation(.easeInOut(duration: Mortar.Motion.normal)) {
                        selectedTileID = isSelected ? nil : tile.id
                    }
                } else {
                    onTap()
                }
            }
    }

    // MARK: - Resize Button

    private var resizeButton: some View {
        Button {
            onResize(nextSize)
        } label: {
            Image(systemName: resizeIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Mortar.IconSize.s, height: Mortar.IconSize.s)
                .background(
                    Circle()
                        .fill(.thinMaterial)
                        .environment(\.colorScheme, .dark)
                )
        }
        .buttonStyle(.plain)
        .padding(6)
        .transition(.scale.combined(with: .opacity))
    }
}

extension View {
    func editableTile(
        _ tile: Tile,
        isEditing: Bool,
        selectedTileID: Binding<Tile.ID?>,
        onResize: @escaping (TileSize) -> Void,
        onTap: @escaping () -> Void
    ) -> some View {
        modifier(EditableTileModifier(
            tile: tile,
            isEditing: isEditing,
            selectedTileID: selectedTileID,
            onResize: onResize,
            onTap: onTap
        ))
    }
}
