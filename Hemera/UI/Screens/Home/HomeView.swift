import SwiftData
import SwiftUI
import Mortar
import TileGridEngine

struct AreasView: View {

    @Bindable var viewModel: AreasViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \AreaEntity.sortOrder) private var areas: [AreaEntity]
    @Query(sort: \FloorEntity.sortOrder) private var floors: [FloorEntity]

    var body: some View {
        UnassignedEntities { unassigned in
            content(hasUnassigned: unassigned.hasAny)
        }
    }

    /// Maps the persisted `Bool` preference to the two-option picker selection.
    private var groupingSelection: Binding<AreaGrouping> {
        Binding(
            get: { viewModel.areasGroupedByFloor ? .byFloor : .none },
            set: { viewModel.areasGroupedByFloor = ($0 == .byFloor) }
        )
    }

    @ViewBuilder
    private func content(hasUnassigned: Bool) -> some View {
        let displayedAreas = viewModel.displayedAreas(from: areas)
        let isEmpty = viewModel.isGridEmpty(displayedAreaCount: displayedAreas.count, hasUnassigned: hasUnassigned)

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
                    AreasEmptyView()
                } else {
                    areaCardGrid(hasUnassigned: hasUnassigned, hasRealAreas: !displayedAreas.isEmpty)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle(Localization.areas)
            .navigationDestination(for: AreaDestination.self) { destination in
                AreaDetailView(viewModel: viewModel.makeDetailViewModel(destination: destination))
            }
            .toolbar {
                // Grouping only has an effect when floors exist, so hide the
                // menu entirely otherwise — a control that does nothing is
                // worse than no control.
                if !floors.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Picker(Localization.grouping, selection: groupingSelection) {
                                ForEach(AreaGrouping.allCases) { option in
                                    Label(option.label, systemImage: option.systemImage).tag(option)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            Label(Localization.viewOptions, systemImage: "ellipsis.circle")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Area Card Grid

private extension AreasView {

    /**
     Stable tile id for the synthetic "Unassigned" card, which has no backing
     `AreaEntity`. Constant so it is distinguishable from real area tiles.
     */
    static let unassignedTileId = UUID(stableForString: "hemera.areas.unassigned")

    /**
     Tile-grid column count. Areas render as `.medium` tiles (2 grid columns
     wide), so 4 columns yields 2-up in compact width and 6 columns keeps the
     roomier 3-up layout in regular width.
     */
    var tileColumns: Int {
        horizontalSizeClass == .compact ? 4 : 6
    }

    /**
     Renders the area grid through the shared `SectionGrid` / `TileGridEngine`,
     so spacing matches the area-detail grid exactly and reordering can be
     enabled later by supplying `isEditing`/`onReorder`. Each floor is one
     section; a headerless section (grouping off / no floors) renders without a
     `SectionHeader`.
     */
    @ViewBuilder
    func areaCardGrid(hasUnassigned: Bool, hasRealAreas: Bool) -> some View {
        let sections = viewModel.sections(
            from: areas,
            floors: floors,
            groupingEnabled: viewModel.areasGroupedByFloor,
            hasUnassigned: hasUnassigned
        )

        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        let areasById = Dictionary(
                            section.areas.map { (UUID(stableForString: $0.areaId), $0) },
                            uniquingKeysWith: { first, _ in first }
                        )

                        VStack(alignment: .leading, spacing: 0) {
                            if let title = section.title, !title.isEmpty {
                                SectionHeader(title, isFirst: index == 0)
                                    .padding(.horizontal, TileGridConstants.padding)
                            }

                            SectionGrid(
                                tiles: .constant(tiles(for: section)),
                                columns: tileColumns,
                                containerWidth: proxy.size.width,
                                isEditing: .constant(false),
                                content: { tile in
                                    areaCell(for: tile, areasById: areasById, hasRealAreas: hasRealAreas)
                                }
                            )
                        }
                    }
                }
                .padding(.vertical, TileGridConstants.sectionPadding)
            }
        }
    }

    /**
     Builds the tile list for a section: one `.medium` tile per area, plus a
     trailing tile for the synthetic "Unassigned" card when the section owns it.
     */
    func tiles(for section: AreasViewModel.AreaSection) -> [Tile] {
        var tiles = section.areas.map { area in
            Tile(id: UUID(stableForString: area.areaId), title: area.name, size: .medium)
        }
        if section.includesUnassigned {
            tiles.append(Tile(id: Self.unassignedTileId, title: "", size: .medium))
        }
        return tiles
    }

    @ViewBuilder
    func areaCell(for tile: Tile, areasById: [UUID: AreaEntity], hasRealAreas: Bool) -> some View {
        if let area = areasById[tile.id] {
            NavigationLink(value: AreaDestination.area(area)) {
                AreaCardView(area: area)
            }
            .buttonStyle(.plain)
        } else if tile.id == Self.unassignedTileId {
            NavigationLink(value: AreaDestination.unassigned(hasRealAreas: hasRealAreas)) {
                unassignedCard(hasRealAreas: hasRealAreas)
            }
            .buttonStyle(.plain)
        }
    }

    func unassignedCard(hasRealAreas: Bool) -> some View {
        let title = AreaDestination.unassigned(hasRealAreas: hasRealAreas).displayName
        return EntityCard {
            CardIcon(
                iconName: "tray",
                backgroundColor: PlatformColor.systemGray3
            )
        } label: {
            CardLabel(title: title, subtitle: "")
        }
        .environment(\.isMediumTile, true)
    }
}

// MARK: - Area Card

private struct AreaCardView: View {
    @Bindable var area: AreaEntity

    private var iconName: String? {
        area.icon.flatMap { MDISymbolMapper.sfSymbol(for: $0) }
    }

    private var statusIcons: [AreaStatusIcon] {
        AreaDisplayHelpers.statusIcons(from: area)
    }

    private var climateLabel: String? {
        let (temp, humidity) = AreaDisplayHelpers.climateSummary(from: area.sensors)
        let parts = [temp, humidity].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        EntityCard {
            CardIcon(
                iconName: iconName ?? "square.grid.2x2",
                backgroundColor: PlatformColor.systemGray3
            )
        } label: {
            CardLabel(title: area.name) {
                if !statusIcons.isEmpty {
                    HStack(spacing: Mortar.Spacing.s) {
                        ForEach(statusIcons) { icon in
                            Image(systemName: icon.iconName)
                                .font(.subheadline)
                                .foregroundStyle(icon.isActive ? icon.activeColor : .gray)
                        }
                    }
                } else if let climate = climateLabel {
                    Text(climate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .environment(\.isMediumTile, true)
    }
}

// MARK: - Localization

// MARK: - Grouping Option

/// The two exclusive grouping options offered in the Areas view-options menu.
/// A view-layer projection of the persisted `areasGroupedByFloor` Bool.
private enum AreaGrouping: String, CaseIterable, Identifiable {
    case byFloor
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .byFloor: AreasView.Localization.groupByFloor
        case .none: AreasView.Localization.noGrouping
        }
    }

    var systemImage: String {
        switch self {
        case .byFloor: "square.stack.3d.up"
        case .none: "square.grid.2x2"
        }
    }
}

// MARK: - Localization

extension AreasView {
    fileprivate enum Localization {
        static let areas = String(localized: "Areas", comment: "Navigation title for the Areas screen showing entities grouped by area")
        static let viewOptions = String(localized: "View Options", comment: "Accessibility label for the toolbar menu button that holds Areas screen display options")
        static let grouping = String(localized: "Grouping", comment: "Header for the grouping options in the Areas view-options menu")
        static let groupByFloor = String(localized: "Group by Floor", comment: "Option in the Areas view-options menu that groups area cards into sections by Home Assistant floor")
        static let noGrouping = String(localized: "No Grouping", comment: "Option in the Areas view-options menu that shows all area cards in a single flat grid without floor sections")
    }
}
