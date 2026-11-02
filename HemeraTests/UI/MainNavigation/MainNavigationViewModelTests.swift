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

    @Test func pills_onlyPinnedFeedsAreUnpinnable() {
        // Built-ins have no way back into the row yet, so they must not offer Unpin.
        let viewModel = makeViewModel(row: [.home, .areas, kitchen])

        #expect(viewModel.pills.map(\.isPinned) == [false, false, true])
    }

    // MARK: - Pinning

    @Test func pin_appendsToRowAndSelectsIt() {
        // Pinning should show its result straight away, at the end where new pins go.
        let viewModel = makeViewModel()

        viewModel.pin(kitchen)

        #expect(viewModel.pills.last?.id == kitchen)
        #expect(viewModel.selectedFeed == kitchen)
    }

    @Test func pin_firstTime_writesFullRow() {
        // Until the first change the row is the code default; after it, the user's row is stored whole.
        let store = InMemorySettingsStore()
        let viewModel = makeViewModel(store: store)
        #expect(store.settings.feedRow == nil)

        viewModel.pin(kitchen)

        #expect(store.settings.feedRow == FeedID.builtIns + [kitchen])
    }

    @Test func pin_alreadyPinned_doesNotDuplicate() {
        // A feed ID appears once, or the pager would hold two pages with one identity.
        let store = InMemorySettingsStore()
        let viewModel = makeViewModel(store: store, row: [.home, kitchen])

        viewModel.pin(kitchen)

        #expect(store.settings.feedRow == [.home, kitchen])
        #expect(viewModel.selectedFeed == kitchen)
    }

    @Test func unpin_removesFromStoredRow() {
        let store = InMemorySettingsStore()
        let viewModel = makeViewModel(store: store, row: [.home, kitchen, .areas])

        viewModel.unpin(kitchen)

        #expect(store.settings.feedRow == [.home, .areas])
        #expect(viewModel.pills.map(\.id) == [.home, .areas])
    }

    @Test func unpin_selectedFeed_selectsHome() {
        // Unpinning what you're looking at must never leave you on a feed that's gone.
        let viewModel = makeViewModel(row: [.home, kitchen])
        viewModel.selectedFeed = kitchen

        viewModel.unpin(kitchen)

        #expect(viewModel.selectedFeed == .home)
    }

    @Test func unpin_otherFeed_keepsSelection() {
        let viewModel = makeViewModel(row: [.home, .areas, kitchen])
        viewModel.selectedFeed = .areas

        viewModel.unpin(kitchen)

        #expect(viewModel.selectedFeed == .areas)
    }

    @Test func unpinnedFeeds_listsPinnableFeedsNotInRow_inResolverOrder() {
        // The + menu stays short and in Home Assistant area order.
        let resolver = StubFeedResolver(pinnableFeeds: [.area("a"), kitchen, .area("c")])
        let viewModel = makeViewModel(resolver: resolver, row: [.home, kitchen])

        #expect(viewModel.unpinnedFeeds.map(\.id) == [.area("a"), .area("c")])
    }

    @Test func unpinnedFeeds_whenEverythingPinned_isEmpty() {
        // Empty is what makes the menu say "All areas pinned" rather than open onto nothing.
        let resolver = StubFeedResolver(pinnableFeeds: [kitchen])
        let viewModel = makeViewModel(resolver: resolver, row: [.home, kitchen])

        #expect(viewModel.unpinnedFeeds.isEmpty)
    }

    // MARK: - Stored row

    @Test func init_unknownAndUnresolvableIDs_areHiddenButKeptOnWrite() {
        // A sync gap or a downgrade must never erase pins: hide them, but write them back unchanged.
        let gone = FeedID.area("deleted")
        let future = FeedID(rawValue: "custom:1234")
        let store = InMemorySettingsStore()
        let viewModel = makeViewModel(
            resolver: StubFeedResolver(unresolvable: [gone, future]),
            store: store,
            row: [.home, gone, future]
        )
        #expect(viewModel.pills.map(\.id) == [.home])

        viewModel.pin(kitchen)

        #expect(store.settings.feedRow == [.home, gone, future, kitchen])
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

    private let kitchen = FeedID.area("kitchen")

    private func makeViewModel(
        resolver: StubFeedResolver? = nil,
        store: InMemorySettingsStore? = nil,
        row: [FeedID]? = nil,
        provider: (any ConnectionStatusProviding)? = nil,
        delay: Duration = .seconds(3)
    ) -> MainNavigationViewModel {
        let store = store ?? InMemorySettingsStore()
        if let row {
            store.settings.feedRow = row
        }
        return MainNavigationViewModel(
            resolver: resolver ?? StubFeedResolver(),
            store: store,
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
    let pinnableFeeds: [FeedID]

    init(unresolvable: Set<FeedID> = [], pinnableFeeds: [FeedID] = []) {
        self.unresolvable = unresolvable
        self.pinnableFeeds = pinnableFeeds
    }

    func summary(for id: FeedID) -> FeedSummary? {
        unresolvable.contains(id) ? nil : FeedSummary(title: id.rawValue, icon: "circle")
    }

    func view(for id: FeedID) -> AnyView { AnyView(EmptyView()) }

    func registerNavigationDestinations(on root: AnyView) -> AnyView { root }
}
