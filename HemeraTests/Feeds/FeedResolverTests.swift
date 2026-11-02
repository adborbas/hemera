import Foundation
import SwiftData
import Testing
@testable import Hemera

@MainActor
struct FeedResolverTests {

    let resolver: FeedResolver
    let context: ModelContext

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: AppEnvironment.createSchema(), configurations: config)
        context = container.mainContext
        let factory = ViewModelFactory(context: container.mainContext, container: container)
        let tileRepo = MockHomeTileRepository()
        let demoCoordinator = MockDemoCoordinator()
        let authManager = MockAuthManager()

        resolver = FeedResolver()
        resolver.registerBuiltInFeeds(
            home: CuratedHomeViewModel(
                homeTileRepository: tileRepo,
                viewModelFactory: factory,
                authManager: authManager,
                demoCoordinator: demoCoordinator
            ),
            areas: AreasViewModel(
                homeTileRepository: tileRepo,
                viewModelFactory: factory,
                demoCoordinator: demoCoordinator,
                authManager: authManager,
                store: InMemorySettingsStore()
            )
        )
        resolver.registerEntityFeeds(
            context: context,
            viewModelFactory: factory,
            homeTileRepository: tileRepo,
            authManager: authManager,
            isDemoMode: false
        )
    }

    // MARK: - Built-in feeds

    @Test func summary_home_alwaysResolves() {
        // Home is the launch feed, so even an empty store must not hide its pill.
        #expect(resolver.summary(for: .home) == FeedSummary(title: "Home", icon: "house"))
    }

    @Test func summary_areas_alwaysResolves() {
        #expect(resolver.summary(for: .areas) == FeedSummary(title: "Areas", icon: "square.grid.2x2"))
    }

    // MARK: - Entity feeds

    @Test func summary_entityFeedWithNoEntities_isNil() {
        // A home without covers must not offer a Covers pill that opens onto nothing.
        #expect(resolver.summary(for: .domain("cover")) == nil)
    }

    @Test func summary_entityFeed_appearsWhenFirstEntityArrives() throws {
        // A device added after launch must bring its pill back without a restart.
        context.insert(ClimateEntity(entityId: "climate.hall", name: "Hall", state: .heat))
        try context.save()

        #expect(resolver.summary(for: .domain("climate")) == FeedSummary(title: "Climate", icon: "thermometer.medium"))
    }

    @Test func summary_entityFeedWithOnlyHiddenEntities_isNil() throws {
        // Everything hidden in Home Assistant means an empty feed, so no pill either.
        let scene = SceneEntity(entityId: "scene.movie", name: "Movie")
        scene.isHiddenInHA = true
        context.insert(scene)
        try context.save()

        #expect(resolver.summary(for: .domain("scene")) == nil)
    }

    @Test func summary_lights_ignoresOtherDomains() throws {
        // Switches often drive lamps, but the Lights feed holds the light domain only.
        context.insert(SwitchEntity(entityId: "switch.lamp", name: "Lamp", state: .on))
        try context.save()

        #expect(resolver.summary(for: .domain("light")) == nil)
        #expect(resolver.summary(for: .domain("switch")) == nil)
    }

    // MARK: - Unknown feeds

    @Test func summary_unregisteredNamespace_isNil() {
        // IDs from a newer build or an unbuilt feed type must hide, not crash or show a blank pill.
        #expect(resolver.summary(for: FeedID(rawValue: "custom:1234")) == nil)
    }

    @Test func summary_namespacedID_matchesWholeNamespace() {
        // Providers own a whole namespace, so `homes:1` is not a Home feed.
        #expect(resolver.summary(for: FeedID(rawValue: "homes:1")) == nil)
        #expect(FeedID(rawValue: "domain:light").namespace == "domain")
    }
}
