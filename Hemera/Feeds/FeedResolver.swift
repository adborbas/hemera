import SwiftData
import SwiftUI
import TileGridEngine

/// What a pill shows for a feed.
struct FeedSummary: Equatable {
    let title: String
    /// SF Symbol name, or an `mdi:` name.
    let icon: String
}

/// Turns feed IDs into what the navigation screen shows, without it knowing what kind of feed it is.
@MainActor
protocol FeedResolving {
    /// `nil` when the feed can't be shown right now; its pill is hidden.
    func summary(for id: FeedID) -> FeedSummary?
    func view(for id: FeedID) -> AnyView
    /// Shown in the header's top row while the feed is selected.
    func actions(for id: FeedID) -> [FeedAction]
    func actionHandler(for id: FeedID) -> (any FeedActionHandling)?
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
        var actions: @MainActor (FeedID) -> [FeedAction] = { _ in [] }
        var actionHandler: @MainActor (FeedID) -> (any FeedActionHandling)? = { _ in nil }
    }

    private var providers: [String: Provider] = [:]

    func register(_ provider: Provider) {
        providers[provider.namespace] = provider
    }

    func registerBuiltInFeeds(home: CuratedHomeViewModel, areas: AreasViewModel, floors: FloorPresence) {
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
            },
            // Grouping does nothing without floors, so the menu is hidden then.
            actions: { _ in floors.hasFloors ? areas.feedActions : [] },
            actionHandler: { _ in areas }
        ))
    }

    func registerEntityFeeds(
        context: ModelContext,
        viewModelFactory: ViewModelFactory,
        homeTileRepository: any HomeTileRepository,
        authManager: any AuthManaging,
        isDemoMode: Bool
    ) {
        func feed<Entity: StoredEntity>(
            _ type: Entity.Type,
            _ title: String,
            _ icon: String,
            _ tileSize: TileSize
        ) -> (String, EntityFeedViewModel) {
            (Entity.domain, EntityFeedViewModel(
                type,
                summary: FeedSummary(title: title, icon: icon),
                tileSize: tileSize,
                context: context,
                viewModelFactory: viewModelFactory,
                homeTileRepository: homeTileRepository,
                haWebViewPresenter: HAWebViewPresenter(authManager: authManager),
                isDemoMode: isDemoMode
            ))
        }
        let feeds = Dictionary(uniqueKeysWithValues: [
            feed(LightEntity.self, Localization.lights, "lightbulb", .small),
            feed(CoverEntity.self, Localization.covers, "blinds.horizontal.closed", .small),
            feed(ClimateEntity.self, Localization.climate, "thermometer.medium", .medium),
            feed(SceneEntity.self, Localization.scenes, "sparkles", .small)
        ])
        register(Provider(
            namespace: FeedID.domain("").namespace,
            summary: { id in feeds[id.value]?.summary },
            view: { id in feeds[id.value].map { AnyView(EntityFeedView(viewModel: $0)) } ?? AnyView(EmptyView()) }
        ))
    }

    // MARK: - FeedResolving

    func summary(for id: FeedID) -> FeedSummary? {
        providers[id.namespace]?.summary(id)
    }

    func view(for id: FeedID) -> AnyView {
        providers[id.namespace]?.view(id) ?? AnyView(EmptyView())
    }

    func actions(for id: FeedID) -> [FeedAction] {
        providers[id.namespace]?.actions(id) ?? []
    }

    func actionHandler(for id: FeedID) -> (any FeedActionHandling)? {
        providers[id.namespace]?.actionHandler(id)
    }

    func registerNavigationDestinations(on root: AnyView) -> AnyView {
        providers.values.reduce(root) { root, provider in provider.navigationDestinations(root) }
    }
}

private extension FeedResolver {
    enum Localization {
        static let home = String(localized: "Home", comment: "Pill label for the Home feed showing pinned entities")
        static let areas = String(localized: "Areas", comment: "Pill label for the Areas feed showing entities grouped by area")
        static let lights = String(localized: "Lights", comment: "Pill label for the feed showing every light, grouped by area")
        static let covers = String(localized: "Covers", comment: "Pill label for the feed showing every cover such as blinds, grouped by area")
        static let climate = String(localized: "Climate", comment: "Pill label for the feed showing every thermostat and AC, grouped by area")
        static let scenes = String(localized: "Scenes", comment: "Pill label for the feed showing every scene, grouped by area")
    }
}
