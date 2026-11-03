import SwiftData
import SwiftUI
import Mortar
import TileGridEngine

struct AreaDetailView: View {
    let viewModel: AreaDetailViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var overlayTransition
    @State private var overlayItem: OverlayItem?
    @State private var hideMode = AreaHideMode()

    var body: some View {
        Group {
            switch viewModel.destination {
            case .area(let area):
                AreaContentView(
                    area: area,
                    viewModel: viewModel,
                    overlayItem: $overlayItem,
                    overlayTransition: overlayTransition,
                    horizontalSizeClass: horizontalSizeClass,
                    isHideMode: hideMode.isActive,
                    animatesTileChanges: hideMode.animatesTileChanges,
                    onEnterHideMode: { setHideMode(true) }
                )
            case .unassigned:
                UnassignedContentView(
                    viewModel: viewModel,
                    overlayItem: $overlayItem,
                    overlayTransition: overlayTransition,
                    horizontalSizeClass: horizontalSizeClass,
                    isHideMode: hideMode.isActive,
                    animatesTileChanges: hideMode.animatesTileChanges,
                    onEnterHideMode: { setHideMode(true) }
                )
            }
        }
        .navigationTitle(viewModel.areaName)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(AreaHeader(
            isEditing: hideMode.isActive,
            title: viewModel.areaName,
            area: area,
            actions: viewModel.feedActions,
            perform: viewModel.perform
        ))
        .toolbar {
            if hideMode.isActive {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Localization.done) {
                        setHideMode(false)
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
        .onDisappear { hideMode.endAnimationWindow() }
    }

    private var area: AreaEntity? {
        if case .area(let area) = viewModel.destination { area } else { nil }
    }

    private func setHideMode(_ on: Bool) {
        if on {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        hideMode.setActive(on)
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
    let overlayTransition: Namespace.ID
    let horizontalSizeClass: UserInterfaceSizeClass?
    let isHideMode: Bool
    let animatesTileChanges: Bool
    let onEnterHideMode: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let columns = viewModel.columnCount(
                isCompactWidth: horizontalSizeClass == .compact,
                size: proxy.size
            )
            let sections = viewModel.sections(for: area, includingHidden: isHideMode)

            ScrollView {
                if sections.isEmpty, !isHideMode, viewModel.hasHiddenEntities(for: area) {
                    AllHiddenPlaceholder(action: onEnterHideMode)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height * 0.7, alignment: .center)
                        .padding(.horizontal, TileGridConstants.padding)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(sections, id: \.id) { section in
                            AreaDetailSection(
                                section: section,
                                viewModel: viewModel,
                                overlayItem: $overlayItem,
                                overlayTransition: overlayTransition,
                                columns: columns,
                                containerWidth: proxy.size.width,
                                isHideMode: isHideMode,
                                animatesTileChanges: animatesTileChanges,
                                onEnterHideMode: onEnterHideMode
                            )
                        }
                    }
                }
            }
            .reportsFeedScroll()
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
    let isHideMode: Bool
    let animatesTileChanges: Bool
    let onEnterHideMode: () -> Void

    var body: some View {
        UnassignedEntities { unassigned in
            GeometryReader { proxy in
                let columns = viewModel.columnCount(
                    isCompactWidth: horizontalSizeClass == .compact,
                    size: proxy.size
                )
                let sections = viewModel.sections(forUnassignedEntityIds: unassigned.entityIds, includingHidden: isHideMode)

                ScrollView {
                    if sections.isEmpty, !isHideMode, unassigned.hasHidden {
                        AllHiddenPlaceholder(action: onEnterHideMode)
                            .frame(maxWidth: .infinity, minHeight: proxy.size.height * 0.7, alignment: .center)
                            .padding(.horizontal, TileGridConstants.padding)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(sections, id: \.id) { section in
                                AreaDetailSection(
                                    section: section,
                                    viewModel: viewModel,
                                    overlayItem: $overlayItem,
                                    overlayTransition: overlayTransition,
                                    columns: columns,
                                    containerWidth: proxy.size.width,
                                    isHideMode: isHideMode,
                                    animatesTileChanges: animatesTileChanges,
                                    onEnterHideMode: onEnterHideMode
                                )
                            }
                        }
                    }
                }
                .reportsFeedScroll()
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
    let isHideMode: Bool
    let animatesTileChanges: Bool
    let onEnterHideMode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = section.title, !title.isEmpty {
                SectionHeader(title)
                    .padding(.horizontal, TileGridConstants.padding)
            }

            SectionGrid(
                tiles: .constant(section.tiles),
                columns: columns,
                containerWidth: containerWidth,
                isEditing: .constant(false),
                animatesTileChanges: animatesTileChanges,
                content: { tile in tileView(for: tile) }
            )
        }
    }

    @ViewBuilder
    private func tileView(for tile: Tile) -> some View {
        if let vm = section.vmsByTileId[tile.id] {
            if isHideMode {
                hideModeTile(for: vm)
            } else {
                vm.makeCardView()
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
                            openInHomeAssistant: { viewModel.openEntityInHA(entityId: vm.id, deviceId: vm.deviceId) },
                            showHideItems: onEnterHideMode
                        )
                    }
            }
        } else {
            EntityCard {
                CardIcon(systemImage: "minus", backgroundColor: PlatformColor.systemGray3)
            } label: {
                CardLabel(title: tile.title, subtitle: "")
            }
        }
    }

    /**
     A card in Show/Hide mode. The card body is inert (`allowsHitTesting(false)`
     so its own controls never fire); a corner button toggles the entity's hidden
     state. Hidden tiles dim; the button shows the action (hide/show) to perform.
    */
    @ViewBuilder
    private func hideModeTile(for vm: any EntityCardViewModel) -> some View {
        vm.makeCardView()
            .allowsHitTesting(false)
            .opacity(vm.isHidden ? 0.4 : 1)
            .overlay(alignment: .bottomTrailing) {
                HideToggleButton(isHidden: vm.isHidden) {
                    vm.isHidden.toggle()
                }
            }
            .animation(Mortar.Motion.springNormal, value: vm.isHidden)
    }
}

// MARK: - FeedActionHandling

/// The area header's "…" menu.
extension AreaDetailViewModel: FeedActionHandling {

    var feedActions: [FeedAction] {
        guard !isDemoMode, !isVirtualArea else { return [] }
        return [FeedAction(
            id: Self.moreOptionsActionId,
            title: AreaDetailView.Localization.moreOptions,
            icon: "ellipsis",
            menu: [FeedMenuItem(
                id: Self.openInHomeAssistantItemId,
                title: AreaDetailView.Localization.openInHomeAssistant,
                icon: "globe",
                isSelected: false
            )]
        )]
    }

    func perform(_ actionID: String, item: String?) {
        guard actionID == Self.moreOptionsActionId, item == Self.openInHomeAssistantItemId else { return }
        openAreaInHA()
    }

    private static let moreOptionsActionId = "moreOptions"
    private static let openInHomeAssistantItemId = "openInHomeAssistant"
}

// MARK: - Localization

private extension AreaDetailView {
    enum Localization {
        static let moreOptions = String(localized: "More Options", comment: "Toolbar button to show additional actions for an area")
        static let openInHomeAssistant = String(localized: "Open in Home Assistant", comment: "Context menu action to open an entity or area in the Home Assistant web interface")
        static let done = String(localized: "Done", comment: "Toolbar button that exits the show/hide-items editing mode for an area")
    }
}
