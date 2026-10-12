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
    @State private var isHideMode = false
    /**
     Gates the Show/Hide reveal/removal animation so it fires only around a mode
     toggle, not during ordinary browsing (e.g. a background sync tile change).
    */
    @State private var animatesTileChanges = false
    @State private var animationResetTask: Task<Void, Never>?

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
                    isHideMode: isHideMode,
                    animatesTileChanges: animatesTileChanges,
                    onEnterHideMode: { setHideMode(true) }
                )
            case .unassigned:
                UnassignedContentView(
                    viewModel: viewModel,
                    overlayItem: $overlayItem,
                    overlayTransition: overlayTransition,
                    horizontalSizeClass: horizontalSizeClass,
                    isHideMode: isHideMode,
                    animatesTileChanges: animatesTileChanges,
                    onEnterHideMode: { setHideMode(true) }
                )
            }
        }
        .navigationTitle(viewModel.areaName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if isHideMode {
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
    }

    /**
     Enters or leaves Show/Hide mode, arming the tile animation for the brief
     transition window only (reset shortly after). A light haptic marks entering.
    */
    private func setHideMode(_ on: Bool) {
        animationResetTask?.cancel()
        animatesTileChanges = true
        isHideMode = on
        if on {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        animationResetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            animatesTileChanges = false
        }
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
            let sections = viewModel.sections(for: area, includingHidden: isHideMode)

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
                    isLandscape: proxy.size.width > proxy.size.height
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
                        if !viewModel.isDemoMode {
                            Button {
                                onEnterHideMode()
                            } label: {
                                Label(Localization.showHideItems, systemImage: "eye.slash")
                            }
                        }
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
            }
        } else {
            EntityCard {
                CardIcon(iconName: "minus", backgroundColor: PlatformColor.systemGray3)
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

// MARK: - Hide Toggle Button

/**
 Toggle control shown in Show/Hide mode, positioned and styled like the Home
 layout resize button. Its icon shows the action it performs — an eye-slash on a
 shown entity (tap to hide), an open eye on a hidden one (tap to show). The
 current state is conveyed by the tile dimming, not the icon.
*/
private struct HideToggleButton: View {
    let isHidden: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                isHidden ? Localization.show : Localization.hide,
                systemImage: isHidden ? "eye" : "eye.slash"
            )
            .labelStyle(.iconOnly)
            .contentTransition(.symbolEffect(.replace))
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

// MARK: - All Hidden Placeholder

/// Shown in an area whose every entity is hidden, giving the user a way back
/// into Show/Hide mode to reveal them (the grid is otherwise empty and offers
/// no tile to long-press).
private struct AllHiddenPlaceholder: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: Mortar.Spacing.m) {
            Image(systemName: "eye.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(Localization.title)
                .font(.headline)
            Text(Localization.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(Localization.showHidden, action: action)
                .buttonStyle(.borderedProminent)
                .padding(.top, Mortar.Spacing.xs)
        }
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

private extension HideToggleButton {
    enum Localization {
        static let hide = String(localized: "Hide", comment: "Accessibility label for the button that hides a currently-shown entity in show/hide mode")
        static let show = String(localized: "Show", comment: "Accessibility label for the button that reveals a currently-hidden entity in show/hide mode")
    }
}

private extension AreaDetailSection {
    enum Localization {
        static let showHideItems = String(localized: "Show/Hide Items", comment: "Context menu action that enters a mode for hiding or revealing entities in an area")
        static let addToHome = String(localized: "Add to Home", comment: "Context menu action to pin an entity to the Home screen")
        static let openInHomeAssistant = String(localized: "Open in Home Assistant", comment: "Context menu action to open an entity or area in the Home Assistant web interface")
    }
}

private extension AllHiddenPlaceholder {
    enum Localization {
        static let title = String(localized: "All Items Hidden", comment: "Title of the placeholder shown when every entity in an area is hidden")
        static let subtitle = String(localized: "Every item in this area is hidden. Reveal items to show them here again.", comment: "Explanation under the all-items-hidden placeholder")
        static let showHidden = String(localized: "Show Hidden Items", comment: "Button that enters show/hide mode so hidden entities can be revealed")
    }
}
