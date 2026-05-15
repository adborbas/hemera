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

        ServiceLocator.configure(
            authManager: authManager,
            router: router,
            demoCoordinator: DemoCoordinator(),
            sessionManager: sessionManager,
            screenManager: ScreenManager()
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
}
