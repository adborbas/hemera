import Foundation
import SwiftData
import Testing
@testable import Hemera

@MainActor
struct AreasViewModelTests {

    let container: ModelContainer
    let context: ModelContext
    let tileRepo: MockHomeTileRepository
    let demoCoordinator: MockDemoCoordinator
    let authManager: MockAuthManager
    let factory: ViewModelFactory

    init() {
        let schema = Schema([
            LightEntity.self, CoverEntity.self, SceneEntity.self, SensorEntity.self,
            SwitchEntity.self, ButtonEntity.self, AutomationEntity.self, BinarySensorEntity.self,
            ClimateEntity.self, AreaEntity.self, HomeTile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        tileRepo = MockHomeTileRepository()
        demoCoordinator = MockDemoCoordinator()
        authManager = MockAuthManager()
        authManager.credentials = ServerCredentials(
            serverURL: URL(string: "http://192.168.1.100:8123")!,
            accessToken: "test",
            refreshToken: "test",
            tokenExpiresAt: .distantFuture,
            clientId: "test"
        )
        factory = ViewModelFactory(context: context, container: container)
        let mockController = MockController()
        factory.registerAllDomains(
            lightController: mockController,
            coverController: mockController,
            sceneController: mockController,
            switchController: mockController,
            buttonController: mockController,
            automationController: mockController,
            climateController: mockController
        )
    }

    private func makeViewModel(
        errorNotifier: ErrorNotifier? = nil,
        connectionRetrier: (any ConnectionRetrying)? = nil,
        resync: @escaping () async -> Void = { }
    ) -> AreasViewModel {
        AreasViewModel(
            homeTileRepository: tileRepo,
            viewModelFactory: factory,
            demoCoordinator: demoCoordinator,
            authManager: authManager,
            errorNotifier: errorNotifier,
            connectionRetrier: connectionRetrier,
            resync: resync
        )
    }

    // MARK: - Demo Mode

    @Test
    func isDemoMode_whenDemoCoordinatorActive_isTrue() {
        demoCoordinator.enter()
        let vm = makeViewModel()
        #expect(vm.isDemoMode == true)
    }

    @Test
    func isDemoMode_whenDemoCoordinatorInactive_isFalse() {
        let vm = makeViewModel()
        #expect(vm.isDemoMode == false)
    }

    // MARK: - Detail Navigation

    @Test
    func makeDetailViewModel_forRealArea_returnsDetailVM() {
        let area = AreaEntity(areaId: "living_room", name: "Living Room")
        context.insert(area)

        let vm = makeViewModel()
        let detailVM = vm.makeDetailViewModel(destination: .area(area))

        #expect(detailVM.areaName == "Living Room")
        #expect(detailVM.isVirtualArea == false)
    }

    @Test
    func makeDetailViewModel_forUnassigned_setsIsVirtualArea() {
        let vm = makeViewModel()
        let detailVM = vm.makeDetailViewModel(destination: .unassigned(hasRealAreas: false))

        #expect(detailVM.isVirtualArea == true)
    }

    // MARK: - Sync Error State

    @Test
    func syncFailed_whenErrorNotifierSyncFailed_returnsTrue() {
        let notifier = ErrorNotifier()
        notifier.markSyncFailed()
        let vm = makeViewModel(errorNotifier: notifier)
        #expect(vm.syncFailed == true)
    }

    @Test
    func syncFailed_whenNoErrorNotifier_returnsFalse() {
        let vm = makeViewModel()
        #expect(vm.syncFailed == false)
    }

    @Test
    func retrySyncAndReload_retriesConnection() {
        let retrier = SpyConnectionRetrier()
        let vm = makeViewModel(connectionRetrier: retrier)

        vm.retrySyncAndReload()

        #expect(vm.isRetrying == true)
        #expect(retrier.retryCallCount == 1)
    }

    // MARK: - Refresh

    @Test
    func refresh_invokesResyncClosure() async {
        let counter = AsyncCounter()
        let vm = makeViewModel(resync: { await counter.increment() })

        await vm.refresh()

        #expect(await counter.value == 1)
    }

    // MARK: - displayedAreas

    @Test
    func displayedAreas_withEntitiesInArea_includesArea() {
        let area = AreaEntity(areaId: "living_room", name: "Living Room")
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .off)
        light.area = area
        context.insert(area)
        context.insert(light)

        let vm = makeViewModel()
        let displayed = vm.displayedAreas(from: [area])

        #expect(displayed.map(\.areaId) == ["living_room"])
    }

    @Test
    func displayedAreas_emptyArea_isFiltered() {
        let empty = AreaEntity(areaId: "empty", name: "Empty")
        context.insert(empty)

        let vm = makeViewModel()
        let displayed = vm.displayedAreas(from: [empty])

        #expect(displayed.isEmpty)
    }

    @Test
    func displayedAreas_areaWithOnlyClimateSensors_isIncluded() {
        let area = AreaEntity(areaId: "kitchen", name: "Kitchen")
        let sensor = SensorEntity(
            entityId: "sensor.temp",
            name: "Temp",
            state: "21",
            deviceClass: "temperature",
            unitOfMeasurement: "°C"
        )
        sensor.area = area
        context.insert(area)
        context.insert(sensor)

        let vm = makeViewModel()
        let displayed = vm.displayedAreas(from: [area])

        #expect(displayed.map(\.areaId) == ["kitchen"])
    }

    @Test
    func displayedAreas_areaWithNonClimateSensorsOnly_isFiltered() {
        let area = AreaEntity(areaId: "hall", name: "Hall")
        let sensor = SensorEntity(
            entityId: "sensor.luminance",
            name: "Luminance",
            state: "42",
            deviceClass: "illuminance",
            unitOfMeasurement: "lx"
        )
        sensor.area = area
        context.insert(area)
        context.insert(sensor)

        let vm = makeViewModel()
        let displayed = vm.displayedAreas(from: [area])

        #expect(displayed.isEmpty)
    }

    @Test
    func displayedAreas_mixedAreas_returnsOnlyPopulated() {
        let populated = AreaEntity(areaId: "lr", name: "Living Room")
        let empty = AreaEntity(areaId: "empty", name: "Empty")
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .off)
        light.area = populated
        context.insert(populated)
        context.insert(empty)
        context.insert(light)

        let vm = makeViewModel()
        let displayed = vm.displayedAreas(from: [populated, empty])

        #expect(displayed.map(\.areaId) == ["lr"])
    }

    // MARK: - isGridEmpty

    @Test
    func isGridEmpty_noAreasAndNoUnassigned_isTrue() {
        let vm = makeViewModel()
        #expect(vm.isGridEmpty(displayedAreaCount: 0, hasUnassigned: false) == true)
    }

    @Test
    func isGridEmpty_noAreasButHasUnassigned_isFalse() {
        let vm = makeViewModel()
        #expect(vm.isGridEmpty(displayedAreaCount: 0, hasUnassigned: true) == false)
    }

    @Test
    func isGridEmpty_withAreas_isFalse() {
        let vm = makeViewModel()
        #expect(vm.isGridEmpty(displayedAreaCount: 1, hasUnassigned: false) == false)
    }
}

private actor AsyncCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

@MainActor
private final class SpyConnectionRetrier: ConnectionRetrying {
    var retryCallCount = 0
    func retryConnection() { retryCallCount += 1 }
}
