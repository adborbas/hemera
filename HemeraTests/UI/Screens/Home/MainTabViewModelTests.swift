import Foundation
import Testing
@testable import Hemera

@MainActor
struct MainTabViewModelTests {

    // MARK: - isConnected

    @Test func isConnected_whenProviderIsConnected_returnsTrue() {
        let provider = StubConnectionStatus(isConnected: true)
        let viewModel = MainTabViewModel(connectionStatusProvider: provider, homeTileRepository: nil)

        #expect(viewModel.isConnected == true)
    }

    @Test func isConnected_whenProviderIsDisconnected_returnsFalse() {
        let provider = StubConnectionStatus(isConnected: false)
        let viewModel = MainTabViewModel(connectionStatusProvider: provider, homeTileRepository: nil)

        #expect(viewModel.isConnected == false)
    }

    @Test func isConnected_whenProviderIsNil_defaultsToTrue() {
        let viewModel = MainTabViewModel(connectionStatusProvider: nil, homeTileRepository: nil)

        #expect(viewModel.isConnected == true)
    }

    // MARK: - showOfflineBanner

    @Test func showOfflineBanner_whenDisconnected_doesNotShowImmediately() {
        let provider = StubConnectionStatus(isConnected: false)
        let viewModel = MainTabViewModel(
            connectionStatusProvider: provider,
            homeTileRepository: nil,
            offlineBannerDelay: .milliseconds(50)
        )

        viewModel.updateBannerVisibility()

        #expect(viewModel.showOfflineBanner == false)
    }

@Test func showOfflineBanner_whenReconnectsBeforeDelay_staysFalse() async throws {
        let provider = StubConnectionStatus(isConnected: false)
        let viewModel = MainTabViewModel(
            connectionStatusProvider: provider,
            homeTileRepository: nil,
            offlineBannerDelay: .milliseconds(500)
        )

        viewModel.updateBannerVisibility()
        provider.isConnected = true
        viewModel.updateBannerVisibility()
        try await Task.sleep(for: .milliseconds(700))

        #expect(viewModel.showOfflineBanner == false)
    }

    // MARK: - hasHomeTiles

    @Test func hasHomeTiles_whenRepositoryHasTiles_returnsTrue() {
        let repo = MockHomeTileRepository()
        repo.stubbedHasAnyHomeTile = true
        let viewModel = MainTabViewModel(connectionStatusProvider: nil, homeTileRepository: repo)

        #expect(viewModel.hasHomeTiles == true)
    }

    @Test func hasHomeTiles_whenRepositoryIsEmpty_returnsFalse() {
        let repo = MockHomeTileRepository()
        let viewModel = MainTabViewModel(connectionStatusProvider: nil, homeTileRepository: repo)

        #expect(viewModel.hasHomeTiles == false)
    }

    @Test func hasHomeTiles_whenRepositoryIsNil_returnsFalse() {
        let viewModel = MainTabViewModel(connectionStatusProvider: nil, homeTileRepository: nil)

        #expect(viewModel.hasHomeTiles == false)
    }
}

// MARK: - Test Doubles

private final class StubConnectionStatus: ConnectionStatusProviding {
    var isConnected: Bool

    init(isConnected: Bool) {
        self.isConnected = isConnected
    }
}
