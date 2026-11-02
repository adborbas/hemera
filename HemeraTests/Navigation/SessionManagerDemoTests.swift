import Foundation
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

        let screenManager = ScreenManager(store: InMemorySettingsStore())
        ServiceLocator.configure(
            authManager: authManager,
            router: router,
            demoCoordinator: DemoCoordinator(),
            sessionManager: sessionManager,
            screenManager: screenManager,
            updateNudge: UpdateNudge(
                lookup: NoAppStoreRelease(),
                screenManager: screenManager,
                installedVersion: "1.0",
                osVersion: "18.0",
                buildMayCheck: false
            ),
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
}
