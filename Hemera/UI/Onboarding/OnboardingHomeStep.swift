import Mortar
import SwiftData
import SwiftUI
import TileGridEngine

/// The Home and Theme steps' content: one grid, editable on Home, inert under the theme editor.
struct OnboardingHomeStep: View {

    let home: CuratedHomeViewModel
    let state: OnboardingCoordinator.HomeState
    let serverHost: String
    let onRetry: () -> Void
    let isTheming: Bool
    let themeResetCount: Int

    @Query(sort: \HomeTile.sortOrder) private var homeTiles: [HomeTile]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How many tiles have arrived; `.max` once the arrival is over, or when the step opens loaded.
    @State private var arrived: Int

    init(
        home: CuratedHomeViewModel,
        state: OnboardingCoordinator.HomeState,
        serverHost: String,
        onRetry: @escaping () -> Void,
        isTheming: Bool,
        themeResetCount: Int
    ) {
        self.home = home
        self.state = state
        self.serverHost = serverHost
        self.onRetry = onRetry
        self.isTheming = isTheming
        self.themeResetCount = themeResetCount
        _arrived = State(initialValue: state == .loaded ? .max : 0)
    }

    private var entityIdByTileId: [Tile.ID: String] {
        Dictionary(uniqueKeysWithValues: homeTiles.map { (UUID(stableForString: $0.entityId), $0.entityId) })
    }

    var body: some View {
        // A ZStack, not a Group, so the state animation reaches the branches' transitions.
        ZStack {
            switch state {
            case .loaded:
                TiledGrid(
                    sections: Binding(
                        get: { [TileSection(tiles: home.displayedTiles(homeTiles: homeTiles))] },
                        set: { home.applyReorder($0.first?.tiles ?? []) }
                    ),
                    isEditing: .constant(!isTheming),
                    onReorder: { previousOrder in
                        home.recordReorderUndo(previousOrder: previousOrder)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    },
                    editBadges: { tile in AnyView(editBadges(for: tile)) }
                ) { tile in
                    tileView(for: tile)
                }
                .allowsHitTesting(reduceMotion || arrived == .max)
                .transition(reduceMotion ? .opacity : .identity)
            case .loading:
                placeholders
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
        .animation(.smooth(duration: 0.35), value: state)
        .environment(\.tilesWiggleWhileEditing, false)
        .task(id: state) { await arrive() }
        // Reseeds until the first edit, so a store write landing after the sync still shows.
        .onChange(of: state == .loaded ? homeTiles.map(\.entityId) : nil, initial: true) {
            if state == .loaded, !home.canUndo, !home.canRedo {
                home.enterEditMode(homeTiles: homeTiles)
            }
        }
        .modifier(OnboardingThemeStep(isShown: isTheming, resetCount: themeResetCount))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isTheming ? "onboardingThemeStep" : "onboardingHomeStep")
    }
}

// MARK: - Loading

private extension OnboardingHomeStep {

    /// A typical Suggested Home's sizes, in the order its rounds fill it.
    static let placeholderTiles = [TileSection(tiles: (0..<SuggestedHome.target).map {
        Tile(title: "", size: [0, 2].contains($0 % 6) ? .medium : .small)
    })]

    var placeholders: some View {
        TiledGrid(sections: .constant(Self.placeholderTiles), isEditing: .constant(false)) { tile in
            EntityCard {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: Mortar.IconSize.m, height: Mortar.IconSize.m)
            } label: {
                CardLabel(title: "Living room", subtitle: "State")
                    .redacted(reason: .placeholder)
            }
            .environment(\.isMediumTile, tile.size == .medium)
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(Localization.loading)
    }

    func arrive() async {
        guard state == .loaded, arrived == 0 else { return }
        if !reduceMotion {
            for count in home.displayedTiles(homeTiles: homeTiles).indices {
                try? await Task.sleep(for: .seconds(0.06))
                arrived = count + 1
            }
            // Editing waits for the last tile's spring to settle.
            try? await Task.sleep(for: .seconds(0.4))
        }
        arrived = .max
    }

    func hasArrived(_ tile: Tile) -> Bool {
        reduceMotion || home.displayedTiles(homeTiles: homeTiles).firstIndex { $0.id == tile.id } ?? 0 < arrived
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
        .opacity(hasArrived(tile) ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: arrived)
    }

    @ViewBuilder
    func tileView(for tile: Tile) -> some View {
        if let entityId = entityIdByTileId[tile.id], let card = home.viewModelFactory.makeViewModel(forEntityId: entityId) {
            card.makeCardView()
                .environment(\.isMediumTile, tile.size == .medium)
                .editableTile(tile, isEditing: true, onTap: {})
                .opacity(hasArrived(tile) ? 1 : 0)
                .scaleEffect(hasArrived(tile) ? 1 : 0.8)
                .animation(.spring(duration: 0.4, bounce: 0.3), value: arrived)
        }
    }
}

/// Undo and redo for the Home step, beside its title.
struct OnboardingHomeHistory: View {

    let home: CuratedHomeViewModel
    let isHomeStep: Bool

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
        .allowsHitTesting(isShown)
    }

    private var isShown: Bool {
        isHomeStep && (home.canUndo || home.canRedo)
    }
}

// MARK: - Localization

private extension OnboardingHomeStep {
    enum Localization {
        static let loading = String(localized: "Loading your Home", comment: "Accessibility label of the placeholder tiles shown while the onboarding Home step loads")
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
