import SwiftUI
import Mortar
import TileGridEngine

// MARK: - Constants

enum TileGridConstants {
    static let columnSpacing: CGFloat = Mortar.Spacing.s
    static let rowSpacing: CGFloat = Mortar.Spacing.s
    static let padding: CGFloat = Mortar.Spacing.l

    /// Base height for a "small" tile in points.
    static let smallTileHeight: CGFloat = 80

    static let sectionSpacing: CGFloat = Mortar.Spacing.xxl
    static let sectionPadding: CGFloat = Mortar.Spacing.s
}

// MARK: - TiledGrid

/// A tiled grid that displays sections of tiles.
///
/// Tiles can be reordered **within a section** via drag and drop.
struct TiledGrid<Content: View>: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Injected model: the sections to display and mutate.
    @Binding var sections: [TileSection]
    @Binding var isEditing: Bool
    var onReorder: (([Tile.ID]) -> Void)?
    var sectionHeaderMenuItems: ((TileSection) -> AnyView?)?
    let content: (Tile) -> Content

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let columns = Self.columns(for: size, horizontalSizeClass: horizontalSizeClass)

            ScrollView {
                VStack(alignment: .leading, spacing: TileGridConstants.sectionSpacing) {
                    ForEach(sections.indices, id: \.self) { index in
                        let section = sections[index]

                        if let title = section.title, !title.isEmpty {
                            VStack(alignment: .leading, spacing: Mortar.Spacing.xxs) {
                                Text(title)
                                    .font(.headline)
                                if let climate = section.climateLabel {
                                    Text(climate)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, TileGridConstants.padding)
                            .contextMenu {
                                if let menuItems = sectionHeaderMenuItems?(section) {
                                    menuItems
                                }
                            }
                        }

                        SectionGrid(
                            tiles: $sections[index].tiles,
                            columns: columns,
                            containerWidth: size.width,
                            isEditing: $isEditing,
                            onReorder: onReorder,
                            content: content
                        )
                    }
                }
                .padding(.vertical, TileGridConstants.sectionPadding)
            }
        }
    }

    private static func columns(for size: CGSize,
                                horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        let isLandscape = size.width > size.height

        if horizontalSizeClass == .compact {
            return 4
        } else {
            return isLandscape ? 12 : 8
        }
    }
}

#if DEBUG
// MARK: - Preview

private struct TiledGrid_PreviewTileView: View {
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

private struct TiledGrid_PreviewWrapper: View {
    @State private var demoSections = [
        TileSection(
            title: "Living room",
            tiles: [
                Tile(title: "Small 1", size: .small),
                Tile(title: "Small 2", size: .small),
                Tile(title: "Medium 1", size: .medium),
                Tile(title: "Large 1", size: .large),
                Tile(title: "Medium 2", size: .medium),
                Tile(title: "Small 3", size: .small),
                Tile(title: "Small 4", size: .small)
            ]
        ),
        TileSection(
            title: "Bedroom",
            tiles: [
                Tile(title: "Large 2", size: .large),
                Tile(title: "Small 5", size: .small),
                Tile(title: "Medium 3", size: .medium)
            ]
        )
    ]
    @State private var isEditing = true

    var body: some View {
        TiledGrid(sections: $demoSections, isEditing: $isEditing) { tile in
            TiledGrid_PreviewTileView(tile: tile)
        }
    }
}

#Preview {
    TiledGrid_PreviewWrapper()
}
#endif
