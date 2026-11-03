import Foundation
import SwiftData
import Testing
@testable import Hemera

@MainActor
struct FeedResolverTests {

    let resolver: FeedResolver
    let context: ModelContext
    let store = InMemorySettingsStore()
    let areas: AreasViewModel

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: AppEnvironment.createSchema(), configurations: config)
        context = container.mainContext
        let factory = ViewModelFactory(context: container.mainContext, container: container)
        let tileRepo = MockHomeTileRepository()
        let demoCoordinator = MockDemoCoordinator()
        let authManager = MockAuthManager()
        authManager.credentials = ServerCredentials(
            serverURL: URL(string: "http://192.168.1.100:8123")!,
            accessToken: "test",
            refreshToken: "test",
            tokenExpiresAt: .distantFuture,
            clientId: "test"
        )

        areas = AreasViewModel(
            homeTileRepository: tileRepo,
            viewModelFactory: factory,
            demoCoordinator: demoCoordinator,
            authManager: authManager,
            store: store
        )
        let floors = FloorPresence(context: context)

        resolver = FeedResolver()
        resolver.registerBuiltInFeeds(
            home: CuratedHomeViewModel(
                homeTileRepository: tileRepo,
                viewModelFactory: factory,
                authManager: authManager,
                demoCoordinator: demoCoordinator
            ),
            areas: areas,
            floors: floors
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

    // MARK: - Area feeds

    // MARK: - Header actions

    @Test func actions_areasWithFloors_offerGroupingMenuCheckingTheCurrentSetting() throws {
        context.insert(FloorEntity(floorId: "ground", name: "Ground", level: 0, sortOrder: 0))
        try context.save()

        let menu = try #require(resolver.actions(for: .areas).first?.menu)

        // Grouping by floor is the default, so its item must carry the checkmark, not No Grouping.
        #expect(menu.map(\.title) == ["Group by Floor", "No Grouping"])
        #expect(menu.map(\.isSelected) == [true, false])
    }

    @Test func actions_areasWithoutFloors_isEmpty() {
        // Grouping has no effect without floors, and a control that does nothing is worse than none.
        #expect(resolver.actions(for: .areas).isEmpty)
    }

    @Test func perform_areasNoGrouping_flipsAndPersistsSettingAndMovesCheckmark() throws {
        context.insert(FloorEntity(floorId: "ground", name: "Ground", level: 0, sortOrder: 0))
        try context.save()
        let action = try #require(resolver.actions(for: .areas).first)
        let noGrouping = try #require(action.menu?.last)

        resolver.actionHandler(for: .areas)?.perform(action.id, item: noGrouping.id)

        // The Areas grid reads the owner, the next launch reads the store, the menu must show the change.
        #expect(areas.areasGroupedByFloor == false)
        #expect(store.settings.areasGroupedByFloor == false)
        #expect(resolver.actions(for: .areas).first?.menu?.map(\.isSelected) == [false, true])
    }

    @Test func actions_homeAndEntityFeeds_areEmpty() throws {
        context.insert(LightEntity(entityId: "light.desk", name: "Desk", state: .on))
        try context.save()

        // Only feeds with something to offer get buttons, so the header stays uncluttered.
        #expect(resolver.actions(for: .home).isEmpty)
        #expect(resolver.actions(for: .domain("light")).isEmpty)
        #expect(resolver.actions(for: FeedID(rawValue: "custom:1234")).isEmpty)
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
