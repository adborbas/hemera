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
    /// Feeds the user can add to the pill row, in the order to offer them.
    var pinnableFeeds: [FeedID] { get }
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
        var pinnableFeeds: @MainActor () -> [FeedID] = { [] }
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

    func registerAreaFeeds(context: ModelContext, areas: AreasViewModel) {
        let areaList = AreaList(context: context)
        register(Provider(
            namespace: FeedID.area("").namespace,
            summary: { id in
                areaList.area(withId: id.value).map { FeedSummary(title: $0.name, icon: $0.icon ?? "mdi:texture-box") }
            },
            view: { id in
                guard let area = areaList.area(withId: id.value) else { return AnyView(EmptyView()) }
                return AnyView(AreaDetailView(viewModel: areas.makeDetailViewModel(destination: .area(area)), isFeed: true))
            },
            pinnableFeeds: { areaList.areas.map { FeedID.area($0.areaId) } }
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

    var pinnableFeeds: [FeedID] {
        providers.keys.sorted().flatMap { providers[$0]?.pinnableFeeds() ?? [] }
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
