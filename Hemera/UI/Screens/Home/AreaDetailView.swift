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
    @State private var hideMode = AreaHideMode()

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
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if hideMode.isActive {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Localization.done) {
                        setHideMode(false)
                    }
                }
            } else if !viewModel.isDemoMode, !viewModel.isVirtualArea {
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
        .onDisappear { hideMode.endAnimationWindow() }
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
    @Binding var showClimateSubtitle: Bool
    let overlayTransition: Namespace.ID
    let horizontalSizeClass: UserInterfaceSizeClass?
    let isHideMode: Bool
    let animatesTileChanges: Bool
    let onEnterHideMode: () -> Void

    /// Held in state so a re-render cannot swap in a fresh, unloaded view model.
    @State private var climateHistoryTarget: ClimateHistoryTarget?

    var body: some View {
        GeometryReader { proxy in
            let columns = viewModel.columnCount(
                isCompactWidth: horizontalSizeClass == .compact,
                size: proxy.size
            )
            let sections = viewModel.sections(for: area, includingHidden: isHideMode)

            ScrollView {
                climateSummaryRow

                if sections.isEmpty, !isHideMode, viewModel.hasHiddenEntities(for: area) {
                    AllHiddenPlaceholder(action: onEnterHideMode)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height * 0.7, alignment: .center)
                        .padding(.horizontal, TileGridConstants.padding)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                            AreaDetailSection(
                                section: section,
                                viewModel: viewModel,
                                overlayItem: $overlayItem,
                                overlayTransition: overlayTransition,
                                columns: columns,
                                containerWidth: proxy.size.width,
                                isFirst: index == 0,
                                isHideMode: isHideMode,
                                animatesTileChanges: animatesTileChanges,
                                onEnterHideMode: onEnterHideMode
                            )
                        }
                    }
                    .padding(.vertical, TileGridConstants.sectionPadding)
                }
            }
            .reportsFeedScroll()
        }
    }

    // MARK: - Climate history sheet

    /// An area's temperature and humidity, each a tappable link to its own history.
    @ViewBuilder
    private var climateSummaryRow: some View {
        let (temperatureText, humidityText) = AreaDisplayHelpers.climateSummary(for: area)
        let representatives = AreaDisplayHelpers.representativeSensors(for: area)

        if temperatureText != nil || humidityText != nil {
            HStack(spacing: Mortar.Spacing.s) {
                if let temperatureText, let temperature = representatives.temperature {
                    climateHistoryButton(
                        text: temperatureText,
                        sensor: temperature,
                        fallbackUnit: "°",
                        icon: "mdi:thermometer"
                    )
                }

                if let humidityText, let humidity = representatives.humidity {
                    climateHistoryButton(
                        text: humidityText,
                        sensor: humidity,
                        fallbackUnit: "%",
                        icon: "mdi:water-percent"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TileGridConstants.padding)
            .opacity(showClimateSubtitle ? 1 : 0)
            .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                showClimateSubtitle = isVisible
            }
            .sheet(item: $climateHistoryTarget) { target in
                AreaClimateHistoryView(
                    viewModel: target.viewModel,
                    areaName: area.name
                )
                .presentationDetents([.large])
            }
        }
    }

    /// 17pt matches the subheadline text; the smallest Mortar.IconSize (19pt) sits above cap height.
    private let readingIconSize: CGFloat = 17

    /// The grid's own shape, so a reading reads as the same material as the cards under it.
    private let readingShape = RoundedRectangle(cornerRadius: Mortar.Radii.s, style: .continuous)

    /// The pill is shorter than this; the hit area is padded out to the HIG minimum around it.
    private let readingTapTarget: CGFloat = 44

    /// A tappable reading that opens its own sensor's history sheet.
    private func climateHistoryButton(
        text: String,
        sensor: SensorEntity,
        fallbackUnit: String,
        icon: String
    ) -> some View {
        Button {
            guard let session = ServiceLocator.shared.session else { return }
            climateHistoryTarget = ClimateHistoryTarget(
                viewModel: AreaClimateHistoryViewModel(
                    sensor: sensor,
                    fallbackUnit: fallbackUnit,
                    provider: session.sensorHistoryProvider
                )
            )
        } label: {
            HStack(spacing: Mortar.Spacing.xs) {
                // Tinted so the glyph reads as its own thing rather than competing with the value.
                MDIIcon(name: icon, size: readingIconSize)
                    .foregroundStyle(Color.cool)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, Mortar.Spacing.m)
            .padding(.vertical, Mortar.Spacing.s)
            .background(PlatformColor.secondarySystemBackground, in: readingShape)
            .frame(minHeight: readingTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Identified by its view model, so a tap is one target for `.sheet(item:)`.
    private struct ClimateHistoryTarget: Identifiable {
        let viewModel: AreaClimateHistoryViewModel
        var id: ObjectIdentifier { ObjectIdentifier(viewModel) }
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
                            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                                AreaDetailSection(
                                    section: section,
                                    viewModel: viewModel,
                                    overlayItem: $overlayItem,
                                    overlayTransition: overlayTransition,
                                    columns: columns,
                                    containerWidth: proxy.size.width,
                                    isFirst: index == 0,
                                    isHideMode: isHideMode,
                                    animatesTileChanges: animatesTileChanges,
                                    onEnterHideMode: onEnterHideMode
                                )
                            }
                        }
                        .padding(.vertical, TileGridConstants.sectionPadding)
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
    let isFirst: Bool
    let isHideMode: Bool
    let animatesTileChanges: Bool
    let onEnterHideMode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = section.title, !title.isEmpty {
                SectionHeader(title, isFirst: isFirst)
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

// MARK: - Localization

private extension AreaDetailView {
    enum Localization {
        static let moreOptions = String(localized: "More Options", comment: "Toolbar button to show additional actions for an area")
        static let openInHomeAssistant = String(localized: "Open in Home Assistant", comment: "Context menu action to open an entity or area in the Home Assistant web interface")
        static let done = String(localized: "Done", comment: "Toolbar button that exits the show/hide-items editing mode for an area")
    }
}
