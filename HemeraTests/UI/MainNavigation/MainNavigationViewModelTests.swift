import Foundation
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct MainNavigationViewModelTests {

    // MARK: - Selection

    @Test func selectedFeed_onLaunch_isHome() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectedFeed == .home)
    }

    @Test func reselectHome_whenSelectedFeedStopsResolving_selectsHome() {
        // A deleted area must not leave the screen on a page that no longer exists.
        let resolver = StubFeedResolver()
        let viewModel = makeViewModel(resolver: resolver, row: FeedID.builtIns + [kitchen])
        viewModel.selectedFeed = kitchen

        resolver.unresolvable = [kitchen]
        viewModel.reselectHomeIfSelectionIsHidden()

        #expect(viewModel.selectedFeed == .home)
    }

    @Test func reselectHome_whenSelectedFeedStillResolves_keepsSelection() {
        let viewModel = makeViewModel()
        viewModel.selectedFeed = .areas

        viewModel.reselectHomeIfSelectionIsHidden()

        #expect(viewModel.selectedFeed == .areas)
    }

    @Test func select_withPushedScreen_popsToTheFeed() {
        // Picking a feed means "show me that feed", not the screen left open over the previous one.
        let viewModel = makeViewModel()
        viewModel.path.append(AreaDestination.unassigned(hasRealAreas: true))

        viewModel.select(.domain("light"))

        #expect(viewModel.selectedFeed == .domain("light"))
        #expect(viewModel.path.isEmpty)
    }

    @Test func reselectHome_whenSelectedFeedStillResolves_keepsPushedScreen() {
        // The pills re-resolve on every data change; an open area screen must not close under the user.
        let viewModel = makeViewModel()
        viewModel.selectedFeed = .areas
        viewModel.path.append(AreaDestination.unassigned(hasRealAreas: true))

        viewModel.reselectHomeIfSelectionIsHidden()

        #expect(viewModel.selectedFeed == .areas)
        #expect(viewModel.path.count == 1)
    }

    // MARK: - Pills

    @Test func pills_withNothingStored_followDefaultRow() {
        let viewModel = makeViewModel()

        #expect(viewModel.pills.map(\.id) == [
            .home, .areas, .domain("light"), .domain("cover"), .domain("climate"), .domain("scene")
        ])
    }

    @Test func pills_whenFeedDoesNotResolve_hidesItsPill() {
        // A feed with nothing to show must never get a pill or a page.
        let resolver = StubFeedResolver(unresolvable: [.areas, .domain("light"), .domain("cover"), .domain("scene")])
        let viewModel = makeViewModel(resolver: resolver)

        #expect(viewModel.pills.map(\.id) == [.home, .domain("climate")])
    }

    // MARK: - Pinning

    // MARK: - Stored row

    @Test func init_unknownAndUnresolvableIDs_areHiddenButKept() {
        // Pins from an earlier build or a newer one must survive: hide their pills, never rewrite the row.
        let gone = FeedID(rawValue: "area:deleted")
        let future = FeedID(rawValue: "custom:1234")
        let store = InMemorySettingsStore()
        let viewModel = makeViewModel(
            resolver: StubFeedResolver(unresolvable: [gone, future]),
            store: store,
            row: [.home, gone, future]
        )

        #expect(viewModel.pills.map(\.id) == [.home])
        #expect(store.settings.feedRow == [.home, gone, future])
    }

    @Test func init_newBuiltIn_isAppendedLastOnce() {
        // Updating the app should surface a new feed without disturbing the user's order.
        let store = InMemorySettingsStore()
        store.settings.feedRow = [.home, kitchen, .areas]
        store.settings.offeredBuiltInFeeds = FeedID.builtIns.filter { $0 != .domain("scene") }

        _ = makeViewModel(store: store)
        #expect(store.settings.feedRow == [.home, kitchen, .areas, .domain("scene")])
        #expect(Set(store.settings.offeredBuiltInFeeds) == Set(FeedID.builtIns))

        store.settings.feedRow = [.home, kitchen]
        _ = makeViewModel(store: store)

        #expect(store.settings.feedRow == [.home, kitchen])
    }

    @Test func init_removedBuiltIn_staysRemoved() {
        // A built-in the user took out of the row must not come back on the next launch.
        let store = InMemorySettingsStore()
        store.settings.feedRow = [.home, .areas]

        let viewModel = makeViewModel(store: store)

        #expect(viewModel.pills.map(\.id) == [.home, .areas])
        #expect(store.settings.feedRow == [.home, .areas])
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

    // MARK: - Title

    @Test func title_beforeHomeNameLoads_isHome() {
        // The header must never show an empty title while the config request is in flight or failed.
        let viewModel = makeViewModel(homeProfile: HomeProfile(homeName: nil))

        #expect(viewModel.title == "Home")
    }

    @Test func title_withBlankLocationName_isHome() {
        // Home Assistant allows clearing the location name; a blank title would look broken.
        #expect(makeViewModel(homeProfile: HomeProfile(homeName: "")).title == "Home")
        #expect(makeViewModel(homeProfile: HomeProfile(homeName: "  ")).title == "Home")
    }

    @Test func title_withLocationName_showsIt() {
        // The title tells the user which home they are looking at.
        let viewModel = makeViewModel(homeProfile: HomeProfile(homeName: "Lake House"))

        #expect(viewModel.title == "Lake House")
    }

    private let kitchen = FeedID(rawValue: "area:kitchen")

    private func makeViewModel(
        resolver: StubFeedResolver? = nil,
        store: InMemorySettingsStore? = nil,
        row: [FeedID]? = nil,
        provider: (any ConnectionStatusProviding)? = nil,
        delay: Duration = .seconds(3),
        homeProfile: HomeProfile? = nil
    ) -> MainNavigationViewModel {
        let store = store ?? InMemorySettingsStore()
        if let row {
            store.settings.feedRow = row
        }
        return MainNavigationViewModel(
            resolver: resolver ?? StubFeedResolver(),
            store: store,
            homeProfile: homeProfile ?? HomeProfile(),
            connectionStatusProvider: provider,
            offlineBannerDelay: delay
        )
    }
}

// MARK: - Test Doubles

private final class StubConnectionStatus: ConnectionStatusProviding {
    var isConnected: Bool

    init(isConnected: Bool) {
        self.isConnected = isConnected
    }
}

private final class StubFeedResolver: FeedResolving {
    var unresolvable: Set<FeedID>

    init(unresolvable: Set<FeedID> = []) {
        self.unresolvable = unresolvable
    }

    func summary(for id: FeedID) -> FeedSummary? {
        unresolvable.contains(id) ? nil : FeedSummary(title: id.rawValue, icon: "circle")
    }

    func view(for id: FeedID) -> AnyView { AnyView(EmptyView()) }

    func actions(for id: FeedID) -> [FeedAction] { [] }

    func actionHandler(for id: FeedID) -> (any FeedActionHandling)? { nil }

    func registerNavigationDestinations(on root: AnyView) -> AnyView { root }
}
