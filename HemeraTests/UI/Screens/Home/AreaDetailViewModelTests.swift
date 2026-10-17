import Foundation
import SwiftData
import Testing
@testable import Hemera

@MainActor
struct AreaDetailViewModelTests {

    let container: ModelContainer
    let context: ModelContext
    let area: AreaEntity
    let tileRepo: MockHomeTileRepository
    let authManager: MockAuthManager
    let haWebViewPresenter: HAWebViewPresenter
    let viewModel: AreaDetailViewModel

    init() {
        let schema = Schema([
            LightEntity.self, CoverEntity.self, SceneEntity.self, ScriptEntity.self, SensorEntity.self,
            SwitchEntity.self, ButtonEntity.self, AutomationEntity.self, BinarySensorEntity.self,
            ClimateEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        area = AreaEntity(areaId: "living_room", name: "Living Room")
        context.insert(area)
        tileRepo = MockHomeTileRepository()
        authManager = MockAuthManager()
        authManager.credentials = ServerCredentials(
            serverURL: URL(string: "http://192.168.1.100:8123")!,
            accessToken: "test",
            refreshToken: "test",
            tokenExpiresAt: .distantFuture,
            clientId: "test"
        )
        haWebViewPresenter = HAWebViewPresenter(authManager: authManager)
        let factory = ViewModelFactory(context: context, container: container)
        let controller = MockController()
        factory.registerAllDomains(
            lightController: controller,
            coverController: controller,
            sceneController: controller,
            scriptController: controller,
            switchController: controller,
            buttonController: controller,
            automationController: controller,
            climateController: controller
        )
        viewModel = AreaDetailViewModel(
            destination: .area(area),
            isDemoMode: false,
            homeTileRepository: tileRepo,
            haWebViewPresenter: haWebViewPresenter,
            viewModelFactory: factory
        )
    }

    // MARK: - Hidden Entity Filtering

    private func insertLight(_ entityId: String, hidden: Bool, haHidden: Bool = false) {
        let light = LightEntity(entityId: entityId, name: entityId, state: .off)
        light.isHidden = hidden
        light.isHiddenInHA = haHidden
        light.area = area
        context.insert(light)
    }

    private func sectionEntityIds(includingHidden: Bool) -> Set<String> {
        Set(viewModel.sections(for: area, includingHidden: includingHidden)
            .flatMap { $0.vmsByTileId.values.map(\.id) })
    }

    // Hidden entities must be absent from the normal grid — that is the whole
    // point of hiding; a hidden light should never render in the area detail.
    @Test
    func sections_whenNotIncludingHidden_dropsHiddenEntities() {
        insertLight("light.visible", hidden: false)
        insertLight("light.hidden", hidden: true)

        #expect(sectionEntityIds(includingHidden: false) == ["light.visible"])
    }

    // In Show/Hide mode the grid must still surface hidden entities, otherwise
    // there would be no way to un-hide one once it is hidden.
    @Test
    func sections_whenIncludingHidden_keepsHiddenEntities() {
        insertLight("light.visible", hidden: false)
        insertLight("light.hidden", hidden: true)

        #expect(sectionEntityIds(includingHidden: true) == ["light.visible", "light.hidden"])
    }

    // Toggling via the card view model must write through to the backing @Model,
    // since the hide flag lives on the entity and drives filtering + persistence.
    @Test
    func isHidden_setViaCardViewModel_writesThroughToEntity() {
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .off)
        context.insert(light)
        let vm = LightCardViewModel(light: light, controller: MockController(), iconResolver: IconTranslationsFixture.resolver())

        #expect(vm.isHidden == false)
        vm.isHidden = true
        #expect(light.isHidden == true)
    }

    // Drives the all-items-hidden placeholder: true when the area still has
    // hidden entities to reveal, false otherwise.
    @Test
    func hasHiddenEntities_whenAnyHidden_isTrue() {
        insertLight("light.visible", hidden: false)
        insertLight("light.hidden", hidden: true)

        #expect(viewModel.hasHiddenEntities(for: area) == true)
    }

    @Test
    func hasHiddenEntities_whenNoneHidden_isFalse() {
        insertLight("light.a", hidden: false)

        #expect(viewModel.hasHiddenEntities(for: area) == false)
    }

    // HA-hidden is the highest-priority filter: the entity never appears, not in
    // the normal grid and not even in Show/Hide mode (unlike our local isHidden).
    @Test
    func sections_haHiddenEntity_excludedEvenInHideMode() {
        insertLight("light.visible", hidden: false)
        insertLight("light.ha_hidden", hidden: false, haHidden: true)

        #expect(sectionEntityIds(includingHidden: false) == ["light.visible"])
        #expect(sectionEntityIds(includingHidden: true) == ["light.visible"])
    }

    // A HA-hidden entity must not count toward the local all-items-hidden placeholder.
    @Test
    func hasHiddenEntities_ignoresHAHidden() {
        insertLight("light.ha_hidden", hidden: false, haHidden: true)

        #expect(viewModel.hasHiddenEntities(for: area) == false)
    }

    // Syncing HA's hidden set both marks newly-hidden entities and clears ones
    // the user un-hid in Home Assistant, so visibility tracks HA on every sync.
    @Test
    func applyHAHidden_marksAndClears() {
        let newlyHidden = LightEntity(entityId: "light.a", name: "a", state: .off)
        let previouslyHidden = LightEntity(entityId: "light.b", name: "b", state: .off)
        previouslyHidden.isHiddenInHA = true
        context.insert(newlyHidden)
        context.insert(previouslyHidden)

        LightEntity.applyHAHidden(hiddenEntityIds: ["light.a"], in: context)

        #expect(newlyHidden.isHiddenInHA == true)
        #expect(previouslyHidden.isHiddenInHA == false)
    }

    // MARK: - Home Tile Delegation

    @Test
    func isOnHome_delegatesToRepository() {
        tileRepo.stubbedOnHome = ["light.lamp"]

        #expect(viewModel.isOnHome(entityId: "light.lamp") == true)
        #expect(viewModel.isOnHome(entityId: "light.other") == false)
    }

    @Test
    func addToHome_delegatesToHomeTileRepository() {
        viewModel.addToHome(entityId: "light.lamp")

        #expect(tileRepo.addToHomeCalls == ["light.lamp"])
    }

    // MARK: - Open in Home Assistant

    @Test
    func openAreaInHA_presentsWebView() async {
        viewModel.openAreaInHA()

        #expect(haWebViewPresenter.url?.path.contains("config/areas/area/living_room") == true)
        await haWebViewPresenter.presentationTask?.value
        #expect(haWebViewPresenter.isPresented == true)
    }

    @Test
    func openAreaInHA_forUnassigned_doesNothing() {
        let factory = ViewModelFactory(context: context, container: container)
        let unassignedVM = AreaDetailViewModel(
            destination: .unassigned(hasRealAreas: true),
            isDemoMode: false,
            homeTileRepository: tileRepo,
            haWebViewPresenter: haWebViewPresenter,
            viewModelFactory: factory
        )

        unassignedVM.openAreaInHA()

        #expect(haWebViewPresenter.url == nil)
    }

    @Test
    func openEntityInHA_withDeviceId_opensDevicePage() async {
        viewModel.openEntityInHA(entityId: "light.lamp", deviceId: "device123")

        #expect(haWebViewPresenter.url?.path.contains("config/devices/device/device123") == true)
        await haWebViewPresenter.presentationTask?.value
        #expect(haWebViewPresenter.isPresented == true)
    }

    @Test
    func openEntityInHA_withoutDeviceId_opensEntityPage() async {
        viewModel.openEntityInHA(entityId: "light.lamp", deviceId: nil)

        #expect(haWebViewPresenter.url?.path.contains("config/entities/entity/light.lamp") == true)
        await haWebViewPresenter.presentationTask?.value
        #expect(haWebViewPresenter.isPresented == true)
    }

    // MARK: - Destination

    @Test
    func areaName_forRealArea_usesAreaName() {
        #expect(viewModel.areaName == "Living Room")
    }

    @Test
    func areaName_forUnassigned_withRealAreas_isOther() {
        let factory = ViewModelFactory(context: context, container: container)
        let unassignedVM = AreaDetailViewModel(
            destination: .unassigned(hasRealAreas: true),
            isDemoMode: false,
            homeTileRepository: tileRepo,
            haWebViewPresenter: haWebViewPresenter,
            viewModelFactory: factory
        )

        #expect(unassignedVM.areaName == "Other")
    }

    @Test
    func areaName_forUnassigned_withoutRealAreas_isDevices() {
        let factory = ViewModelFactory(context: context, container: container)
        let unassignedVM = AreaDetailViewModel(
            destination: .unassigned(hasRealAreas: false),
            isDemoMode: false,
            homeTileRepository: tileRepo,
            haWebViewPresenter: haWebViewPresenter,
            viewModelFactory: factory
        )

        #expect(unassignedVM.areaName == "Devices")
    }

    @Test
    func isVirtualArea_forRealArea_isFalse() {
        #expect(viewModel.isVirtualArea == false)
    }

    @Test
    func isVirtualArea_forUnassigned_isTrue() {
        let factory = ViewModelFactory(context: context, container: container)
        let unassignedVM = AreaDetailViewModel(
            destination: .unassigned(hasRealAreas: true),
            isDemoMode: false,
            homeTileRepository: tileRepo,
            haWebViewPresenter: haWebViewPresenter,
            viewModelFactory: factory
        )

        #expect(unassignedVM.isVirtualArea == true)
    }
}
