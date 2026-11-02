import Foundation

@Observable
@MainActor
final class MainNavigationViewModel {

    struct Pill: Identifiable, Equatable {
        let id: FeedID
        let summary: FeedSummary
    }

    var selectedFeed: FeedID = .home
    private(set) var showOfflineBanner = false

    let resolver: any FeedResolving

    private let feedRow: [FeedID] = [.home, .areas]
    private let connectionStatusProvider: (any ConnectionStatusProviding)?
    private let offlineBannerDelay: Duration
    private var offlineBannerTask: Task<Void, Never>?

    /// One per feed in the row that can be shown right now, in row order.
    var pills: [Pill] {
        feedRow.compactMap { id in
            resolver.summary(for: id).map { Pill(id: id, summary: $0) }
        }
    }

    var isConnected: Bool {
        connectionStatusProvider?.isConnected ?? true
    }

    init(
        resolver: any FeedResolving,
        connectionStatusProvider: (any ConnectionStatusProviding)?,
        offlineBannerDelay: Duration = .seconds(3)
    ) {
        self.resolver = resolver
        self.connectionStatusProvider = connectionStatusProvider
        self.offlineBannerDelay = offlineBannerDelay
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
