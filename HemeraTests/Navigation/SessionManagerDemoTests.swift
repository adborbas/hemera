import Foundation
import HAKit
import SwiftData
import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct SessionManagerTests {

    let sessionManager: SessionManager
    let persistentContainer: ModelContainer
    let authManager: MockAuthManager

    init() {
        let authManager = MockAuthManager()
        let router = AppRouter(authManager: authManager)
        let schema = AppEnvironment.createSchema()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let storage = SwiftDataStorage(context: container.mainContext)

        let sessionManager = SessionManager(
            authManager: authManager,
            router: router,
            container: container,
            storage: storage
        )

        ServiceLocator.configure(
            authManager: authManager,
            router: router,
            demoCoordinator: DemoCoordinator(),
            sessionManager: sessionManager,
            screenManager: ScreenManager(store: InMemorySettingsStore()),
            settingsStore: InMemorySettingsStore()
        )

        self.authManager = authManager
        self.persistentContainer = container
        self.sessionManager = sessionManager
    }

    // MARK: - startDemoSession

    @Test
    func startDemoSession_doesNotWriteToPersistentStore() {
        sessionManager.startDemoSession()

        let context = persistentContainer.mainContext
        let areaCount = (try? context.fetchCount(FetchDescriptor<AreaEntity>())) ?? -1
        let lightCount = (try? context.fetchCount(FetchDescriptor<LightEntity>())) ?? -1
        let tileCount = (try? context.fetchCount(FetchDescriptor<HomeTile>())) ?? -1

        #expect(areaCount == 0)
        #expect(lightCount == 0)
        #expect(tileCount == 0)
    }

    @Test
    func startDemoSession_createsSession() {
        sessionManager.startDemoSession()

        #expect(ServiceLocator.shared.session != nil)
    }

    @Test
    func inMemoryDemoContainer_withCurrentSchema_buildsAndIsQueryable() throws {
        /**
         Guards the graceful demo-container fallback in `startDemoSession`: if the
         current schema ever stopped building an in-memory container, the demo path
         would silently no-op. This fails loudly instead.
         */
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AppEnvironment.createSchema(), configurations: config)
        let count = try container.mainContext.fetchCount(FetchDescriptor<AreaEntity>())
        #expect(count == 0)
    }

    // MARK: - tearDownDemoSession

    @Test
    func tearDownDemoSession_clearsSession() {
        sessionManager.startDemoSession()

        sessionManager.tearDownDemoSession()

        #expect(ServiceLocator.shared.session == nil)
    }

    // MARK: - handleScenePhase

    @Test
    func handleScenePhase_withNoSession_doesNotCrash() {
        sessionManager.handleScenePhase(.background)
        sessionManager.handleScenePhase(.active)
    }

    @Test
    func handleScenePhase_inDemoMode_doesNotCrash() {
        sessionManager.startDemoSession()

        sessionManager.handleScenePhase(.background)
        sessionManager.handleScenePhase(.active)
    }

    @Test
    func handleScenePhase_afterTeardown_doesNotCrash() {
        sessionManager.startDemoSession()
        sessionManager.tearDownDemoSession()

        sessionManager.handleScenePhase(.background)
        sessionManager.handleScenePhase(.active)
    }

    // MARK: - Logout Wipe

    /// Logging out must leave nothing of the old account behind — every model, not a chosen few.
    @Test
    func logout_wipesEveryModelInTheSchema() throws {
        let context = persistentContainer.mainContext
        context.insert(FloorEntity(floorId: "floor.ground", name: "Ground floor"))
        context.insert(AreaEntity(areaId: "area.lobby", name: "Lobby"))
        context.insert(HomeTile(entityId: "light.lobby", sortOrder: 0))
        context.insert(LightEntity(entityId: "light.lobby", name: "Lobby", state: .on))
        try context.save()

        // Logout alone drives the wipe; authenticating first would open a real socket.
        authManager.logout()

        #expect(try context.fetch(FetchDescriptor<FloorEntity>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AreaEntity>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HomeTile>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<LightEntity>()).isEmpty)
    }

    /// A kiosk iPad whose token expires must come back with its Home intact after a new login.
    @Test
    func sessionExpiry_keepsLocalData() throws {
        let context = persistentContainer.mainContext
        context.insert(AreaEntity(areaId: "area.lobby", name: "Lobby"))
        context.insert(HomeTile(entityId: "light.lobby", sortOrder: 0))
        context.insert(LightEntity(entityId: "light.lobby", name: "Lobby", state: .on))
        try context.save()

        authManager.simulateSessionExpiry()

        #expect(try context.fetch(FetchDescriptor<AreaEntity>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<HomeTile>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<LightEntity>()).count == 1)
    }

    @Test
    func sessionExpiry_clearsSession() {
        sessionManager.startDemoSession()

        authManager.simulateSessionExpiry()

        #expect(ServiceLocator.shared.session == nil)
    }

    // MARK: - Suggested Home

    @Test
    func fillSuggestedHome_afterLoginFromLoggedOut_fillsHome() throws {
        let payload = try syncedLamp()

        authManager.simulateLogin()
        sessionManager.fillSuggestedHomeIfNeeded(payload)

        #expect(homeTileIds() == ["light.lamp"])
    }

    /// A returning user's Home is theirs; only a login can suggest one.
    @Test
    func fillSuggestedHome_onLaunchWhileLoggedIn_leavesHomeAlone() throws {
        let payload = try syncedLamp()
        let loggedIn = MockAuthManager()
        loggedIn.state = .authenticated
        let manager = SessionManager(
            authManager: loggedIn,
            router: AppRouter(authManager: loggedIn),
            container: persistentContainer,
            storage: SwiftDataStorage(context: persistentContainer.mainContext)
        )

        manager.startIfAuthenticated()
        manager.fillSuggestedHomeIfNeeded(payload)

        #expect(homeTileIds().isEmpty)
    }

    /// Logging back in after an expiry is not onboarding, so a Home the user emptied stays empty.
    @Test
    func fillSuggestedHome_afterLoginFromSessionExpired_leavesHomeAlone() throws {
        let payload = try syncedLamp()
        authManager.simulateLogin()
        authManager.simulateSessionExpiry()

        authManager.simulateLogin()
        sessionManager.fillSuggestedHomeIfNeeded(payload)

        #expect(homeTileIds().isEmpty)
    }

    @Test
    func fillSuggestedHome_inDemoMode_leavesHomeAlone() throws {
        let payload = try syncedLamp()

        sessionManager.startDemoSession()
        sessionManager.fillSuggestedHomeIfNeeded(payload)

        #expect(homeTileIds().isEmpty)
    }

    @Test
    func fillSuggestedHome_whenHomeHasTiles_addsNothing() throws {
        let payload = try syncedLamp()
        persistentContainer.mainContext.insert(HomeTile(entityId: "light.mine", sortOrder: 0))

        authManager.simulateLogin()
        sessionManager.fillSuggestedHomeIfNeeded(payload)

        #expect(homeTileIds() == ["light.mine"])
    }

    /// A resync or reconnect finishes another sync; Home must not refill behind a user who cleared it.
    @Test
    func fillSuggestedHome_onASecondSync_addsNothing() throws {
        let payload = try syncedLamp()
        authManager.simulateLogin()
        sessionManager.fillSuggestedHomeIfNeeded(payload)
        SwiftDataStorage(context: persistentContainer.mainContext).removeHomeTile(entityId: "light.lamp")

        sessionManager.fillSuggestedHomeIfNeeded(payload)

        #expect(homeTileIds().isEmpty)
    }

    // MARK: - Helpers

    /// Stores what a sync of one lamp leaves behind and returns the payload it fetched.
    private func syncedLamp() throws -> HADataSyncService.SyncPayload {
        let context = persistentContainer.mainContext
        let area = AreaEntity(areaId: "area.lobby", name: "Lobby")
        context.insert(area)
        let lamp = LightEntity(entityId: "light.lamp", name: "Lamp", state: .on)
        context.insert(lamp)
        lamp.area = area
        try context.save()

        let state = try HAEntity(
            entityId: "light.lamp",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: nil, parentId: nil)
        )
        return HADataSyncService.SyncPayload(
            entities: [state],
            areaMappings: [],
            deviceMappings: [],
            hiddenEntityIds: [],
            areaSortOrder: [:],
            areaIcons: [:],
            areaTemperatureEntityIds: [:],
            areaHumidityEntityIds: [:],
            areaMappingsFetchSucceeded: true,
            floors: nil,
            floorSortOrder: [:],
            areaFloorIds: [:],
            iconTranslations: nil,
            entityRegistry: EntityRegistrySnapshot.decode(HAData(value: [["entity_id": "light.lamp", "original_name": "Lamp"]]))
        )
    }

    private func homeTileIds() -> [String] {
        SwiftDataStorage(context: persistentContainer.mainContext).homeTiles().map(\.entityId)
    }
}
