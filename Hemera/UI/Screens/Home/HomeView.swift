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

    static let areaCardHeight: CGFloat =
        TileGridConstants.smallTileHeight * 2 + TileGridConstants.rowSpacing

    var gridColumns: [GridItem] {
        let count = horizontalSizeClass == .compact ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: Mortar.Spacing.s), count: count)
    }

    @ViewBuilder
    func areaCardGrid(hasUnassigned: Bool, hasRealAreas: Bool) -> some View {
        let sections = viewModel.sections(
            from: areas,
            floors: floors,
            groupingEnabled: viewModel.areasGroupedByFloor,
            hasUnassigned: hasUnassigned
        )

        ScrollView {
            if sections.count == 1, sections[0].title == nil {
                // Flat layout — no floors (or grouping off). Rendered exactly
                // as before, with no section headers.
                LazyVGrid(columns: gridColumns, spacing: Mortar.Spacing.s) {
                    areaCells(for: sections[0], hasRealAreas: hasRealAreas)
                }
                .padding(TileGridConstants.padding)
            } else {
                LazyVStack(spacing: Mortar.Spacing.s) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        Section {
                            LazyVGrid(columns: gridColumns, spacing: Mortar.Spacing.s) {
                                areaCells(for: section, hasRealAreas: hasRealAreas)
                            }
                        } header: {
                            sectionHeader(section.title ?? "", isFirst: index == 0)
                        }
                    }
                }
                .padding(TileGridConstants.padding)
            }
        }
    }

    @ViewBuilder
    func areaCells(for section: AreasViewModel.AreaSection, hasRealAreas: Bool) -> some View {
        ForEach(section.areas) { area in
            NavigationLink(value: AreaDestination.area(area)) {
                AreaCardView(area: area)
                    .frame(height: Self.areaCardHeight)
            }
            .buttonStyle(.plain)
        }
        if section.includesUnassigned {
            NavigationLink(value: AreaDestination.unassigned(hasRealAreas: hasRealAreas)) {
                unassignedCard(hasRealAreas: hasRealAreas)
                    .frame(height: Self.areaCardHeight)
            }
            .buttonStyle(.plain)
        }
    }

    /// Floor section title. Scrolls away with its grid (no pinning). Bold,
    /// primary-colour heading with extra top breathing room for every floor
    /// after the first (the first sits close under the nav title).
    func sectionHeader(_ title: String, isFirst: Bool) -> some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, isFirst ? 0 : Mortar.Spacing.l)
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
