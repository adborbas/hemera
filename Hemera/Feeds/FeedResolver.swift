import SwiftUI

/// What a pill shows for a feed.
struct FeedSummary: Equatable {
    let title: String
    /// SF Symbol name.
    let icon: String
}

/// Turns feed IDs into what the navigation screen shows, without it knowing what kind of feed it is.
@MainActor
protocol FeedResolving {
    /// `nil` when the feed can't be shown right now; its pill is hidden.
    func summary(for id: FeedID) -> FeedSummary?
    func view(for id: FeedID) -> AnyView
    /// Pages come and go as the pager moves, so feeds register destinations on the stack root here.
    func registerNavigationDestinations(on root: AnyView) -> AnyView
}

/// Session-scoped resolver that delegates each feed ID to the provider registered for its namespace.
@MainActor
final class FeedResolver: FeedResolving {

    struct Provider {
        let namespace: String
        let summary: @MainActor (FeedID) -> FeedSummary?
        let view: @MainActor (FeedID) -> AnyView
        var navigationDestinations: @MainActor (AnyView) -> AnyView = { $0 }
    }

    private var providers: [String: Provider] = [:]

    func register(_ provider: Provider) {
        providers[provider.namespace] = provider
    }

    func registerBuiltInFeeds(home: CuratedHomeViewModel, areas: AreasViewModel) {
        register(Provider(
            namespace: FeedID.home.namespace,
            summary: { _ in FeedSummary(title: Localization.home, icon: "house") },
            view: { _ in AnyView(CuratedHomeView(viewModel: home)) }
        ))
        register(Provider(
            namespace: FeedID.areas.namespace,
            summary: { _ in FeedSummary(title: Localization.areas, icon: "square.grid.2x2") },
            view: { _ in AnyView(AreasView(viewModel: areas)) },
            navigationDestinations: { root in
                AnyView(root.navigationDestination(for: AreaDestination.self) { destination in
                    AreaDetailView(viewModel: areas.makeDetailViewModel(destination: destination))
                })
            }
        ))
    }

    // MARK: - FeedResolving

    func summary(for id: FeedID) -> FeedSummary? {
        providers[id.namespace]?.summary(id)
    }

    func view(for id: FeedID) -> AnyView {
        providers[id.namespace]?.view(id) ?? AnyView(EmptyView())
    }

    func registerNavigationDestinations(on root: AnyView) -> AnyView {
        providers.values.reduce(root) { root, provider in provider.navigationDestinations(root) }
    }
}

private extension FeedResolver {
    enum Localization {
        static let home = String(localized: "Home", comment: "Pill label for the Home feed showing pinned entities")
        static let areas = String(localized: "Areas", comment: "Pill label for the Areas feed showing entities grouped by area")
    }
}
