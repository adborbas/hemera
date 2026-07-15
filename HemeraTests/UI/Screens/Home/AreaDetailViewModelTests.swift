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
            LightEntity.self, CoverEntity.self, SceneEntity.self, SensorEntity.self,
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
        viewModel = AreaDetailViewModel(
            destination: .area(area),
            isDemoMode: false,
            homeTileRepository: tileRepo,
            haWebViewPresenter: haWebViewPresenter,
            viewModelFactory: factory
        )
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
