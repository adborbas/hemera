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
            ClimateEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self
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
            areaDisplaySettings: AreaDisplaySettings(),
            errorNotifier: errorNotifier,
            connectionRetrier: connectionRetrier,
            resync: resync
        )
    }

    // Inserts an area with one light so it survives the `displayedAreas` filter,
    // optionally attaching it to a floor.
    @discardableResult
    private func makePopulatedArea(id: String, name: String, sortOrder: Int = 0, floor: FloorEntity? = nil) -> AreaEntity {
        let area = AreaEntity(areaId: id, name: name, sortOrder: sortOrder)
        area.floor = floor
        let light = LightEntity(entityId: "light.\(id)", name: "\(name) Lamp", state: .off)
        light.area = area
        context.insert(area)
        context.insert(light)
        return area
    }

    @discardableResult
    private func makeFloor(id: String, name: String, level: Int?, sortOrder: Int) -> FloorEntity {
        let floor = FloorEntity(floorId: id, name: name, level: level, sortOrder: sortOrder)
        context.insert(floor)
        return floor
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

    // MARK: - sections

    @Test
    func sections_groupingDisabled_returnsSingleHeaderlessSection() {
        let ground = makeFloor(id: "ground", name: "Ground Floor", level: 0, sortOrder: 0)
        let lr = makePopulatedArea(id: "living_room", name: "Living Room", sortOrder: 0, floor: ground)

        let vm = makeViewModel()
        let sections = vm.sections(from: [lr], floors: [ground], groupingEnabled: false, hasUnassigned: false)

        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(sections[0].areas.map(\.areaId) == ["living_room"])
        #expect(sections[0].includesUnassigned == false)
    }

    @Test
    func sections_noFloors_returnsSingleHeaderlessSection() {
        let lr = makePopulatedArea(id: "living_room", name: "Living Room", sortOrder: 0)

        let vm = makeViewModel()
        let sections = vm.sections(from: [lr], floors: [], groupingEnabled: true, hasUnassigned: false)

        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(sections[0].areas.map(\.areaId) == ["living_room"])
    }

    @Test
    func sections_flatSection_carriesUnassignedFlag() {
        let vm = makeViewModel()
        let sections = vm.sections(from: [], floors: [], groupingEnabled: true, hasUnassigned: true)

        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(sections[0].areas.isEmpty)
        #expect(sections[0].includesUnassigned == true)
    }

    @Test
    func areasGroupedByFloor_togglingProperty_flipsGroupingOutput() {
        let ground = makeFloor(id: "ground", name: "Ground Floor", level: 0, sortOrder: 0)
        let kitchen = makePopulatedArea(id: "kitchen", name: "Kitchen", sortOrder: 0, floor: ground)

        let vm = makeViewModel()

        // On → grouped into a floor section.
        vm.areasGroupedByFloor = true
        #expect(vm.areasGroupedByFloor == true)
        let grouped = vm.sections(from: [kitchen], floors: [ground], groupingEnabled: vm.areasGroupedByFloor, hasUnassigned: false)
        #expect(grouped.map(\.title) == ["Ground Floor"])

        // Off → single headerless (flat) section.
        vm.areasGroupedByFloor = false
        #expect(vm.areasGroupedByFloor == false)
        let flat = vm.sections(from: [kitchen], floors: [ground], groupingEnabled: vm.areasGroupedByFloor, hasUnassigned: false)
        #expect(flat.count == 1)
        #expect(flat[0].title == nil)
        #expect(flat[0].areas.map(\.areaId) == ["kitchen"])
    }

    @Test
    func sections_grouped_oneSectionPerFloorInSortOrder() {
        let ground = makeFloor(id: "ground", name: "Ground Floor", level: 0, sortOrder: 0)
        let upstairs = makeFloor(id: "upstairs", name: "Upstairs", level: 1, sortOrder: 1)
        let kitchen = makePopulatedArea(id: "kitchen", name: "Kitchen", sortOrder: 0, floor: ground)
        let bedroom = makePopulatedArea(id: "bedroom", name: "Bedroom", sortOrder: 1, floor: upstairs)

        let vm = makeViewModel()
        // Pass floors out of order to prove the function sorts by sortOrder.
        let sections = vm.sections(from: [kitchen, bedroom], floors: [upstairs, ground], groupingEnabled: true, hasUnassigned: false)

        #expect(sections.map(\.title) == ["Ground Floor", "Upstairs"])
        #expect(sections[0].areas.map(\.areaId) == ["kitchen"])
        #expect(sections[1].areas.map(\.areaId) == ["bedroom"])
        #expect(sections.allSatisfy { !$0.includesUnassigned })
    }

    @Test
    func sections_grouped_floorlessAreasGoToOtherSectionLast() {
        let ground = makeFloor(id: "ground", name: "Ground Floor", level: 0, sortOrder: 0)
        let kitchen = makePopulatedArea(id: "kitchen", name: "Kitchen", sortOrder: 0, floor: ground)
        let garden = makePopulatedArea(id: "garden", name: "Garden", sortOrder: 1)

        let vm = makeViewModel()
        let sections = vm.sections(from: [kitchen, garden], floors: [ground], groupingEnabled: true, hasUnassigned: false)

        #expect(sections.count == 2)
        #expect(sections[0].title == "Ground Floor")
        #expect(sections.last?.title == "Other")
        #expect(sections.last?.areas.map(\.areaId) == ["garden"])
    }

    @Test
    func sections_grouped_emptyFloorIsDropped() {
        let ground = makeFloor(id: "ground", name: "Ground Floor", level: 0, sortOrder: 0)
        let upstairs = makeFloor(id: "upstairs", name: "Upstairs", level: 1, sortOrder: 1)
        // Only the ground floor has a populated area; upstairs is empty.
        let kitchen = makePopulatedArea(id: "kitchen", name: "Kitchen", sortOrder: 0, floor: ground)

        let vm = makeViewModel()
        let sections = vm.sections(from: [kitchen], floors: [ground, upstairs], groupingEnabled: true, hasUnassigned: false)

        #expect(sections.map(\.title) == ["Ground Floor"])
    }

    @Test
    func sections_grouped_emptyAreaFilteredOutOfFloor() {
        let ground = makeFloor(id: "ground", name: "Ground Floor", level: 0, sortOrder: 0)
        let kitchen = makePopulatedArea(id: "kitchen", name: "Kitchen", sortOrder: 0, floor: ground)
        // Empty area on the same floor — no entities, so filtered by displayedAreas.
        let empty = AreaEntity(areaId: "empty", name: "Empty", sortOrder: 1)
        empty.floor = ground
        context.insert(empty)

        let vm = makeViewModel()
        let sections = vm.sections(from: [kitchen, empty], floors: [ground], groupingEnabled: true, hasUnassigned: false)

        #expect(sections.count == 1)
        #expect(sections[0].areas.map(\.areaId) == ["kitchen"])
    }

    @Test
    func sections_grouped_unassignedOnlyStillGetsOtherHeader() {
        let ground = makeFloor(id: "ground", name: "Ground Floor", level: 0, sortOrder: 0)
        let kitchen = makePopulatedArea(id: "kitchen", name: "Kitchen", sortOrder: 0, floor: ground)

        let vm = makeViewModel()
        let sections = vm.sections(from: [kitchen], floors: [ground], groupingEnabled: true, hasUnassigned: true)

        #expect(sections.count == 2)
        #expect(sections.last?.title == "Other")
        #expect(sections.last?.areas.isEmpty == true)
        #expect(sections.last?.includesUnassigned == true)
    }

    @Test
    func sections_grouped_noOtherSectionWhenNoFloorlessAreasOrUnassigned() {
        let ground = makeFloor(id: "ground", name: "Ground Floor", level: 0, sortOrder: 0)
        let kitchen = makePopulatedArea(id: "kitchen", name: "Kitchen", sortOrder: 0, floor: ground)

        let vm = makeViewModel()
        let sections = vm.sections(from: [kitchen], floors: [ground], groupingEnabled: true, hasUnassigned: false)

        #expect(sections.count == 1)
        #expect(sections[0].title == "Ground Floor")
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
