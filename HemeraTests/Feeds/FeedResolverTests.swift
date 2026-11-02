import Foundation
import SwiftData
import Testing
@testable import Hemera

@MainActor
struct FeedResolverTests {

    let resolver: FeedResolver

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: AppEnvironment.createSchema(), configurations: config)
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
    }

    // MARK: - Built-in feeds

    @Test func summary_home_alwaysResolves() {
        // Home is the launch feed, so even an empty store must not hide its pill.
        #expect(resolver.summary(for: .home) == FeedSummary(title: "Home", icon: "house"))
    }

    @Test func summary_areas_alwaysResolves() {
        #expect(resolver.summary(for: .areas) == FeedSummary(title: "Areas", icon: "square.grid.2x2"))
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
