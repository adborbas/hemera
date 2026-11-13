import Mortar
import SwiftData
import SwiftUI
import TileGridEngine

/// The Home step's content: Home's edit mode on the Suggested Home, without the wiggle.
struct OnboardingHomeStep: View {

    let home: CuratedHomeViewModel
    let state: OnboardingCoordinator.HomeState
    let serverHost: String
    let onRetry: () -> Void

    @Query(sort: \HomeTile.sortOrder) private var homeTiles: [HomeTile]

    private var entityIdByTileId: [Tile.ID: String] {
        Dictionary(uniqueKeysWithValues: homeTiles.map { (UUID(stableForString: $0.entityId), $0.entityId) })
    }

    var body: some View {
        Group {
            switch state {
            case .loaded:
                TiledGrid(
                    sections: Binding(
                        get: { [TileSection(tiles: home.displayedTiles(homeTiles: homeTiles))] },
                        set: { home.applyReorder($0.first?.tiles ?? []) }
                    ),
                    isEditing: .constant(true),
                    onReorder: { previousOrder in
                        home.recordReorderUndo(previousOrder: previousOrder)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    },
                    editBadges: { tile in AnyView(editBadges(for: tile)) }
                ) { tile in
                    tileView(for: tile)
                }
            case .loading:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Localization.loading)
            case .failed:
                unableToConnect
            case .empty:
                ContentUnavailableView {
                    Text(Localization.emptyTitle)
                } description: {
                    Text(Localization.emptyMessage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.tilesWiggleWhileEditing, false)
        // Reseeds until the first edit, so a store write landing after the sync still shows.
        .onChange(of: state == .loaded ? homeTiles.map(\.entityId) : nil, initial: true) {
            if state == .loaded, !home.canUndo, !home.canRedo {
                home.enterEditMode(homeTiles: homeTiles)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboardingHomeStep")
    }
}

// MARK: - Unable to Connect

private extension OnboardingHomeStep {

    /// Matches the Connecting screen's timed-out state.
    var unableToConnect: some View {
        VStack(spacing: Mortar.Spacing.xxl) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: Mortar.IconSize.m))
                .foregroundStyle(.secondary)

            Text(Localization.unableToConnect)
                .font(.title2.bold())

            Text(Localization.couldNotReach(serverHost))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Mortar.PanelSpacing.edge)

            Button(Localization.retry, action: onRetry)
                .buttonStyle(.mortarPrimary())
                .accessibilityIdentifier("onboardingHomeRetry")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tiles

private extension OnboardingHomeStep {

    func editBadges(for tile: Tile) -> some View {
        TileEditBadges(
            tile: tile,
            onRemove: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { home.removeTile(tile) }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            },
            onResize: { targetSize in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { home.resizeTile(tile, to: targetSize) }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        )
    }

    @ViewBuilder
    func tileView(for tile: Tile) -> some View {
        if let entityId = entityIdByTileId[tile.id], let card = home.viewModelFactory.makeViewModel(forEntityId: entityId) {
            card.makeCardView()
                .environment(\.isMediumTile, tile.size == .medium)
                .editableTile(tile, isEditing: true, onTap: {})
        }
    }
}

/// Undo and redo for the Home step, beside its title.
struct OnboardingHomeHistory: View {

    let home: CuratedHomeViewModel

    var body: some View {
        HStack(spacing: Mortar.Spacing.s) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { home.performUndo() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label(Localization.undo, systemImage: "arrow.uturn.backward")
                    .labelStyle(.iconOnly)
            }
            .disabled(!home.canUndo)
            .accessibilityIdentifier("onboardingHomeUndo")

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { home.performRedo() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label(Localization.redo, systemImage: "arrow.uturn.forward")
                    .labelStyle(.iconOnly)
            }
            .disabled(!home.canRedo)
            .accessibilityIdentifier("onboardingHomeRedo")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        // Hidden, not removed, so the title row keeps its height.
        .opacity(isShown ? 1 : 0)
        .accessibilityHidden(!isShown)
    }

    private var isShown: Bool {
        home.canUndo || home.canRedo
    }
}

// MARK: - Localization

private extension OnboardingHomeStep {
    enum Localization {
        static let loading = String(localized: "Loading your Home", comment: "Accessibility label of the spinner shown while the onboarding Home step loads")
        static let unableToConnect = String(localized: "Unable to Connect", comment: "Title shown when the app cannot reach the Home Assistant server")
        static let retry = String(localized: "Retry", comment: "Button to retry connecting to the server")
        static func couldNotReach(_ host: String) -> String {
            String(localized: "Could not reach \(host). Make sure you're on the same network as your Home Assistant server.", comment: "Error message shown when connection to the server times out, with the server hostname")
        }
        static let emptyTitle = String(localized: "Nothing to suggest yet", comment: "Title shown in the onboarding Home step when the server has no devices to suggest for Home")
        static let emptyMessage = String(
            localized: "Hemera didn't find any lights, switches or other devices to put on your Home. You can add tiles from Areas at any time.",
            comment: "Message shown in the onboarding Home step when the server has no devices to suggest for Home"
        )
    }
}

private extension OnboardingHomeHistory {
    enum Localization {
        static let undo = String(localized: "Undo", comment: "Button undoing the last change to Home during onboarding")
        static let redo = String(localized: "Redo", comment: "Button redoing the last undone change to Home during onboarding")
    }
}
