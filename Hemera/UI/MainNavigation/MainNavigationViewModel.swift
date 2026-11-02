import Foundation

@Observable
@MainActor
final class MainNavigationViewModel {

    struct Pill: Identifiable, Equatable {
        let id: FeedID
        let summary: FeedSummary
        /// Added by the user, so it can be unpinned; built-ins can't.
        var isPinned: Bool { !FeedID.builtIns.contains(id) }
    }

    var selectedFeed: FeedID = .home
    private(set) var showOfflineBanner = false

    let resolver: any FeedResolving
    let homeProfile: HomeProfile

    /// Unknown and unresolvable IDs stay in here, so a sync gap or a downgrade never loses a pin.
    private(set) var feedRow: [FeedID]? {
        didSet { store.settings.feedRow = feedRow }
    }

    private let store: any SettingsStoring
    private let connectionStatusProvider: (any ConnectionStatusProviding)?
    private let offlineBannerDelay: Duration
    private var offlineBannerTask: Task<Void, Never>?

    private var row: [FeedID] {
        feedRow ?? FeedID.builtIns
    }

    /// One per feed in the row that can be shown right now, in row order.
    var pills: [Pill] {
        row.compactMap(pill(for:))
    }

    /// What the + menu offers: pinnable feeds not already in the row.
    var unpinnedFeeds: [Pill] {
        resolver.pinnableFeeds.filter { !row.contains($0) }.compactMap(pill(for:))
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
        self.store = store
        self.homeProfile = homeProfile

        // Built-ins added since the last launch go last, once; one the user removed stays removed.
        var settings = store.settings
        let newBuiltIns = FeedID.builtIns.filter { !settings.offeredBuiltInFeeds.contains($0) }
        settings.feedRow = settings.feedRow.map { row in row + newBuiltIns.filter { !row.contains($0) } }
        settings.offeredBuiltInFeeds += newBuiltIns
        if settings != store.settings {
            store.settings = settings
        }
        self.feedRow = settings.feedRow
        self.connectionStatusProvider = connectionStatusProvider
        self.offlineBannerDelay = offlineBannerDelay
    }

    func pin(_ id: FeedID) {
        if !row.contains(id) {
            feedRow = row + [id]
        }
        selectedFeed = id
    }

    func unpin(_ id: FeedID) {
        feedRow = row.filter { $0 != id }
        reselectHomeIfSelectionIsHidden()
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
