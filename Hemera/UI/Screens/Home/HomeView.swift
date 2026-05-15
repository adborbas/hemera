import SwiftData
import SwiftUI
import Mortar
import TileGridEngine

struct AreasView: View {

    var viewModel: AreasViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \AreaEntity.sortOrder) private var areas: [AreaEntity]

    var body: some View {
        UnassignedEntities { unassigned in
            content(hasUnassigned: unassigned.hasAny)
        }
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
                    areaCardGrid(displayedAreas: displayedAreas, hasUnassigned: hasUnassigned)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle(Localization.areas)
            .navigationDestination(for: AreaDestination.self) { destination in
                AreaDetailView(viewModel: viewModel.makeDetailViewModel(destination: destination))
            }
        }
    }
}

// MARK: - Area Card Grid

private extension AreasView {

    static let areaCardHeight: CGFloat =
        TileGridConstants.smallTileHeight * 2 + TileGridConstants.rowSpacing

    var gridColumns: [GridItem] {
        let count = horizontalSizeClass == .compact ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: Mortar.Spacing.s), count: count)
    }

    func areaCardGrid(displayedAreas: [AreaEntity], hasUnassigned: Bool) -> some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: Mortar.Spacing.s) {
                ForEach(displayedAreas) { area in
                    NavigationLink(value: AreaDestination.area(area)) {
                        AreaCardView(area: area)
                            .frame(height: Self.areaCardHeight)
                    }
                    .buttonStyle(.plain)
                }
                if hasUnassigned {
                    let hasRealAreas = !displayedAreas.isEmpty
                    NavigationLink(value: AreaDestination.unassigned(hasRealAreas: hasRealAreas)) {
                        unassignedCard(hasRealAreas: hasRealAreas)
                            .frame(height: Self.areaCardHeight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(TileGridConstants.padding)
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

private extension AreasView {
    enum Localization {
        static let areas = String(localized: "Areas", comment: "Navigation title for the Areas screen showing entities grouped by area")
    }
}
