import SwiftUI

@Observable
@MainActor
final class MainNavigationViewModel {

    struct Pill: Identifiable, Equatable {
        let id: FeedID
        let summary: FeedSummary
    }

    /// Owned here, not by either layout, so a size-class change keeps the feed and any pushed screen.
    var selectedFeed: FeedID = .home
    var path = NavigationPath()
    private(set) var showOfflineBanner = false

    let resolver: any FeedResolving
    let homeProfile: HomeProfile

    /// The stored row as is: unknown and unresolvable IDs stay, only their pills are hidden.
    private let row: [FeedID]

    private let connectionStatusProvider: (any ConnectionStatusProviding)?
    private let offlineBannerDelay: Duration
    private var offlineBannerTask: Task<Void, Never>?

    /// One per feed in the row that can be shown right now, in row order.
    var pills: [Pill] {
        row.compactMap(pill(for:))
    }

    var title: String { homeProfile.displayName }

    var isConnected: Bool {
        connectionStatusProvider?.isConnected ?? true
    }

    init(
        resolver: any FeedResolving,
        store: any SettingsStoring,
        homeProfile: HomeProfile,
        connectionStatusProvider: (any ConnectionStatusProviding)?,
        offlineBannerDelay: Duration = .seconds(3)
    ) {
        self.resolver = resolver
        self.homeProfile = homeProfile

        // Built-ins added since the last launch go last, once; one the user removed stays removed.
        var settings = store.settings
        let newBuiltIns = FeedID.builtIns.filter { !settings.offeredBuiltInFeeds.contains($0) }
        settings.feedRow = settings.feedRow.map { row in row + newBuiltIns.filter { !row.contains($0) } }
        settings.offeredBuiltInFeeds += newBuiltIns
        if settings != store.settings {
            store.settings = settings
        }
        self.row = settings.feedRow ?? FeedID.builtIns
        self.connectionStatusProvider = connectionStatusProvider
        self.offlineBannerDelay = offlineBannerDelay
    }

    /// Shows a feed at the root, leaving any pushed screen.
    func select(_ id: FeedID) {
        selectedFeed = id
        path = NavigationPath()
    }

    /// Call when the pills change: a selected feed that stopped resolving has no page left to show.
    func reselectHomeIfSelectionIsHidden() {
        if !pills.contains(where: { $0.id == selectedFeed }) {
            selectedFeed = .home
        }
    }

    func updateBannerVisibility() {
        offlineBannerTask?.cancel()
        if isConnected {
            showOfflineBanner = false
        } else {
            offlineBannerTask = Task {
                try? await Task.sleep(for: offlineBannerDelay)
                guard !Task.isCancelled else { return }
                showOfflineBanner = true
            }
        }
    }
}

private extension MainNavigationViewModel {
    func pill(for id: FeedID) -> Pill? {
        resolver.summary(for: id).map { Pill(id: id, summary: $0) }
    }
}
