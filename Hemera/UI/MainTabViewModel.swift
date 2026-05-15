import Foundation

@Observable
@MainActor
final class MainTabViewModel {

    let hasHomeTiles: Bool
    private(set) var showOfflineBanner = false

    private let connectionStatusProvider: (any ConnectionStatusProviding)?
    private let offlineBannerDelay: Duration
    private var offlineBannerTask: Task<Void, Never>?

    var isConnected: Bool {
        connectionStatusProvider?.isConnected ?? true
    }

    init(
        connectionStatusProvider: (any ConnectionStatusProviding)?,
        homeTileRepository: (any HomeTileRepository)?,
        offlineBannerDelay: Duration = .seconds(3)
    ) {
        self.connectionStatusProvider = connectionStatusProvider
        self.hasHomeTiles = homeTileRepository?.hasAnyHomeTile() ?? false
        self.offlineBannerDelay = offlineBannerDelay
    }

    convenience init() {
        let sl = ServiceLocator.shared
        self.init(
            connectionStatusProvider: sl.session?.connectionStatusProvider,
            homeTileRepository: sl.session?.homeTileRepository
        )
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
