import SwiftData
import SwiftUI
import Mortar
import TileGridEngine

struct AreaDetailView: View {
    let viewModel: AreaDetailViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var overlayTransition
    @State private var showClimateSubtitle = true
    @State private var overlayItem: OverlayItem?

    var body: some View {
        Group {
            switch viewModel.destination {
            case .area(let area):
                AreaContentView(
                    area: area,
                    viewModel: viewModel,
                    overlayItem: $overlayItem,
                    showClimateSubtitle: $showClimateSubtitle,
                    overlayTransition: overlayTransition,
                    horizontalSizeClass: horizontalSizeClass
                )
            case .unassigned:
                UnassignedContentView(
                    viewModel: viewModel,
                    overlayItem: $overlayItem,
                    overlayTransition: overlayTransition,
                    horizontalSizeClass: horizontalSizeClass
                )
            }
        }
        .navigationTitle(viewModel.areaName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !viewModel.isDemoMode, !viewModel.isVirtualArea {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.openAreaInHA()
                        } label: {
                            Label(Localization.openInHomeAssistant, systemImage: "globe")
                        }
                    } label: {
                        Label(Localization.moreOptions, systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                    }
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
}

// MARK: - Area Content

/// Renders the categorized entity grid for a real area. Reads entities
/// directly from the area's relationships, looks up VMs via the factory's
/// session-scoped cache, and re-renders when any of the underlying `@Model`
/// properties change.
private struct AreaContentView: View {

    @Bindable var area: AreaEntity
    let viewModel: AreaDetailViewModel
    @Binding var overlayItem: OverlayItem?
    @Binding var showClimateSubtitle: Bool
    let overlayTransition: Namespace.ID
    let horizontalSizeClass: UserInterfaceSizeClass?

    private var climateLabel: String? {
        let (temp, humidity) = AreaDisplayHelpers.climateSummary(from: area.sensors)
        let parts = [temp, humidity].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        GeometryReader { proxy in
            let columns = viewModel.columnCount(
                isCompactWidth: horizontalSizeClass == .compact,
                isLandscape: proxy.size.width > proxy.size.height
            )

            ScrollView {
                if let climate = climateLabel {
                    Text(climate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, TileGridConstants.padding)
                        .opacity(showClimateSubtitle ? 1 : 0)
                        .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                            showClimateSubtitle = isVisible
                        }
                }

                VStack(alignment: .leading, spacing: TileGridConstants.sectionSpacing) {
                    ForEach(viewModel.sections(for: area), id: \.id) { section in
                        AreaDetailSection(
                            section: section,
                            viewModel: viewModel,
                            overlayItem: $overlayItem,
                            overlayTransition: overlayTransition,
                            columns: columns,
                            containerWidth: proxy.size.width
                        )
                    }
                }
                .padding(.vertical, TileGridConstants.sectionPadding)
            }
        }
    }
}

// MARK: - Unassigned Content

/// Renders the virtual "Other" area: entities not assigned to any HA area.
/// `UnassignedEntities` owns the per-domain `@Query`s so the predicates
/// stay in one place across screens.
private struct UnassignedContentView: View {

    let viewModel: AreaDetailViewModel
    @Binding var overlayItem: OverlayItem?
    let overlayTransition: Namespace.ID
    let horizontalSizeClass: UserInterfaceSizeClass?

    var body: some View {
        UnassignedEntities { unassigned in
            GeometryReader { proxy in
                let columns = viewModel.columnCount(
                isCompactWidth: horizontalSizeClass == .compact,
                isLandscape: proxy.size.width > proxy.size.height
            )

                ScrollView {
                    VStack(alignment: .leading, spacing: TileGridConstants.sectionSpacing) {
                        ForEach(viewModel.sections(forUnassignedEntityIds: unassigned.entityIds), id: \.id) { section in
                            AreaDetailSection(
                                section: section,
                                viewModel: viewModel,
                                overlayItem: $overlayItem,
                                overlayTransition: overlayTransition,
                                columns: columns,
                                containerWidth: proxy.size.width
                            )
                        }
                    }
                    .padding(.vertical, TileGridConstants.sectionPadding)
                }
            }
        }
    }
}

// MARK: - Section

private struct AreaDetailSection: View {
    let section: CategorizedSection
    let viewModel: AreaDetailViewModel
    @Binding var overlayItem: OverlayItem?
    let overlayTransition: Namespace.ID
    let columns: Int
    let containerWidth: CGFloat

    var body: some View {
        if let title = section.title, !title.isEmpty {
            Text(title)
                .font(.headline)
                .padding(.horizontal, TileGridConstants.padding)
        }

        SectionGrid(
            tiles: .constant(section.tiles),
            columns: columns,
            containerWidth: containerWidth,
            isEditing: .constant(false),
            content: { tile in tileView(for: tile) }
        )
    }

    @ViewBuilder
    private func tileView(for tile: Tile) -> some View {
        if let vm = section.vmsByTileId[tile.id] {
            vm.makeCardView()
                .matchedTransitionSource(id: vm.id, in: overlayTransition)
                .onTapGesture {
                    if let target = viewModel.viewModelFactory.handleCardTap(entityId: vm.id) {
                        overlayItem = OverlayItem(id: target.id, viewModel: target)
                    }
                }
                .contextMenu {
                    if !viewModel.isOnHome(entityId: vm.id) {
                        Button {
                            viewModel.addToHome(entityId: vm.id)
                        } label: {
                            Label(Localization.addToHome, systemImage: "plus")
                        }
                    }
                    if !viewModel.isDemoMode {
                        Button {
                            viewModel.openEntityInHA(entityId: vm.id, deviceId: vm.deviceId)
                        } label: {
                            Label(Localization.openInHomeAssistant, systemImage: "globe")
                        }
                    }
                }
        } else {
            EntityCard {
                CardIcon(iconName: "minus", backgroundColor: PlatformColor.systemGray3)
            } label: {
                CardLabel(title: tile.title, subtitle: "")
            }
        }
    }
}

// MARK: - Localization

private extension AreaDetailView {
    enum Localization {
        static let moreOptions = String(localized: "More Options", comment: "Toolbar button to show additional actions for an area")
        static let openInHomeAssistant = String(localized: "Open in Home Assistant", comment: "Context menu action to open an entity or area in the Home Assistant web interface")
    }
}

private extension AreaDetailSection {
    enum Localization {
        static let addToHome = String(localized: "Add to Home", comment: "Context menu action to pin an entity to the Home screen")
        static let openInHomeAssistant = String(localized: "Open in Home Assistant", comment: "Context menu action to open an entity or area in the Home Assistant web interface")
    }
}
