import Foundation
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct MainNavigationViewModelTests {

    // MARK: - Selection

    @Test func selectedFeed_onLaunch_isHome() {
        let viewModel = MainNavigationViewModel(resolver: StubFeedResolver(), connectionStatusProvider: nil)

        #expect(viewModel.selectedFeed == .home)
    }

    // MARK: - Pills

    @Test func pills_followRowOrder() {
        let viewModel = MainNavigationViewModel(resolver: StubFeedResolver(), connectionStatusProvider: nil)

        #expect(viewModel.pills.map(\.id) == [.home, .areas])
    }

    @Test func pills_whenFeedDoesNotResolve_hidesItsPill() {
        // A feed with nothing to show must never get a pill or a page.
        let resolver = StubFeedResolver(unresolvable: [.areas])
        let viewModel = MainNavigationViewModel(resolver: resolver, connectionStatusProvider: nil)

        #expect(viewModel.pills.map(\.id) == [.home])
    }

    // MARK: - isConnected

    @Test func isConnected_whenProviderIsConnected_returnsTrue() {
        let viewModel = makeViewModel(provider: StubConnectionStatus(isConnected: true))

        #expect(viewModel.isConnected == true)
    }

    @Test func isConnected_whenProviderIsDisconnected_returnsFalse() {
        let viewModel = makeViewModel(provider: StubConnectionStatus(isConnected: false))

        #expect(viewModel.isConnected == false)
    }

    @Test func isConnected_whenProviderIsNil_defaultsToTrue() {
        let viewModel = makeViewModel(provider: nil)

        #expect(viewModel.isConnected == true)
    }

    // MARK: - showOfflineBanner

    @Test func showOfflineBanner_whenDisconnected_doesNotShowImmediately() {
        let viewModel = makeViewModel(provider: StubConnectionStatus(isConnected: false), delay: .milliseconds(50))

        viewModel.updateBannerVisibility()

        #expect(viewModel.showOfflineBanner == false)
    }

    @Test func showOfflineBanner_whenReconnectsBeforeDelay_staysFalse() async throws {
        let provider = StubConnectionStatus(isConnected: false)
        let viewModel = makeViewModel(provider: provider, delay: .milliseconds(500))

        viewModel.updateBannerVisibility()
        provider.isConnected = true
        viewModel.updateBannerVisibility()
        try await Task.sleep(for: .milliseconds(700))

        #expect(viewModel.showOfflineBanner == false)
    }

    private func makeViewModel(
        provider: (any ConnectionStatusProviding)?,
        delay: Duration = .seconds(3)
    ) -> MainNavigationViewModel {
        MainNavigationViewModel(resolver: StubFeedResolver(), connectionStatusProvider: provider, offlineBannerDelay: delay)
    }
}

// MARK: - Test Doubles

private final class StubConnectionStatus: ConnectionStatusProviding {
    var isConnected: Bool

    init(isConnected: Bool) {
        self.isConnected = isConnected
    }
}

private struct StubFeedResolver: FeedResolving {
    var unresolvable: Set<FeedID> = []

    func summary(for id: FeedID) -> FeedSummary? {
        unresolvable.contains(id) ? nil : FeedSummary(title: id.rawValue, icon: "circle")
    }

    func view(for id: FeedID) -> AnyView { AnyView(EmptyView()) }

    func registerNavigationDestinations(on root: AnyView) -> AnyView { root }
}
