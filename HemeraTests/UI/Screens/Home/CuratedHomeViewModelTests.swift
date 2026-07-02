import Foundation
import SwiftData
import TileGridEngine
import Testing
@testable import Hemera

@MainActor
struct CuratedHomeViewModelTests {

    let container: ModelContainer
    let context: ModelContext
    let tileRepo: MockHomeTileRepository
    let authManager: MockAuthManager
    let factory: ViewModelFactory

    init() {
        let schema = Schema([
            LightEntity.self, CoverEntity.self, SceneEntity.self, SensorEntity.self,
            SwitchEntity.self, ButtonEntity.self, AutomationEntity.self, AreaEntity.self, HomeTile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        tileRepo = MockHomeTileRepository()
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
        connectionRetrier: (any ConnectionRetrying)? = nil
    ) -> CuratedHomeViewModel {
        CuratedHomeViewModel(
            homeTileRepository: tileRepo,
            viewModelFactory: factory,
            authManager: authManager,
            demoCoordinator: MockDemoCoordinator(),
            errorNotifier: errorNotifier,
            connectionRetrier: connectionRetrier
        )
    }

    private func makeTile(entityId: String, size: TileSize = .small) -> Tile {
        Tile(id: UUID(stableForString: entityId), title: entityId, size: size)
    }

    // MARK: - Edit Mode

    @Test
    func enterEditMode_seedsDraftTilesAndSetsEditing() {
        let vm = makeViewModel()
        let tileA = makeTile(entityId: "light.a")
        let tileB = makeTile(entityId: "light.b")

        vm.enterEditMode(seed: [(tile: tileA, entityId: "light.a"), (tile: tileB, entityId: "light.b")])

        #expect(vm.isEditing == true)
        #expect(vm.draftTiles?.count == 2)
        #expect(vm.undoStack.isEmpty)
    }

    @Test
    func exitEditMode_withoutCommit_clearsDraftAndDoesNotWriteRepo() {
        let vm = makeViewModel()
        vm.enterEditMode(seed: [(makeTile(entityId: "light.a"), "light.a")])

        vm.exitEditMode(commit: false)

        #expect(vm.isEditing == false)
        #expect(vm.draftTiles == nil)
        #expect(tileRepo.commitLayoutCalls.isEmpty)
    }

    @Test
    func exitEditMode_withCommit_writesLayoutToRepository() {
        let vm = makeViewModel()
        let tileA = makeTile(entityId: "light.a", size: .small)
        let tileB = makeTile(entityId: "light.b", size: .medium)
        vm.enterEditMode(seed: [(tileA, "light.a"), (tileB, "light.b")])

        vm.exitEditMode(commit: true)

        #expect(tileRepo.commitLayoutCalls.count == 1)
        let call = tileRepo.commitLayoutCalls[0]
        #expect(call.count == 2)
        #expect(call[0].entityId == "light.a")
        #expect(call[0].sortOrder == 0)
        #expect(call[0].size == .small)
        #expect(call[1].entityId == "light.b")
        #expect(call[1].sortOrder == 1)
        #expect(call[1].size == .medium)
        #expect(vm.isEditing == false)
        #expect(vm.draftTiles == nil)
    }

    @Test
    func applyReorder_updatesDraftTiles() {
        let vm = makeViewModel()
        let tileA = makeTile(entityId: "light.a")
        let tileB = makeTile(entityId: "light.b")
        vm.enterEditMode(seed: [(tileA, "light.a"), (tileB, "light.b")])

        vm.applyReorder([tileB, tileA])

        #expect(vm.draftTiles?.map(\.id) == [tileB.id, tileA.id])
    }

    @Test
    func applyReorder_outsideEditMode_isIgnored() {
        let vm = makeViewModel()
        let tile = makeTile(entityId: "light.a")

        vm.applyReorder([tile])

        #expect(vm.draftTiles == nil)
    }

    @Test
    func resizeTile_updatesDraftAndRecordsUndo() {
        let vm = makeViewModel()
        let tile = makeTile(entityId: "light.a", size: .small)
        vm.enterEditMode(seed: [(tile, "light.a")])

        vm.resizeTile(tile, to: .medium)

        #expect(vm.draftTiles?.first?.size == .medium)
        #expect(vm.canUndo == true)
    }

    @Test
    func performUndo_afterResize_restoresPreviousSize() {
        let vm = makeViewModel()
        let tile = makeTile(entityId: "light.a", size: .small)
        vm.enterEditMode(seed: [(tile, "light.a")])
        vm.resizeTile(tile, to: .medium)

        vm.performUndo()

        #expect(vm.draftTiles?.first?.size == .small)
        #expect(vm.canUndo == false)
    }

    @Test
    func performUndo_afterReorder_restoresPreviousOrder() {
        let vm = makeViewModel()
        let tileA = makeTile(entityId: "light.a")
        let tileB = makeTile(entityId: "light.b")
        vm.enterEditMode(seed: [(tileA, "light.a"), (tileB, "light.b")])
        vm.recordReorderUndo(previousOrder: [tileA.id, tileB.id])
        vm.applyReorder([tileB, tileA])

        vm.performUndo()

        #expect(vm.draftTiles?.map(\.id) == [tileA.id, tileB.id])
    }

    @Test
    func performRedo_afterUndoingResize_reappliesTheResize() {
        let vm = makeViewModel()
        let tile = makeTile(entityId: "light.a", size: .small)
        vm.enterEditMode(seed: [(tile, "light.a")])
        vm.resizeTile(tile, to: .medium)
        vm.performUndo()
        #expect(vm.canRedo == true)

        vm.performRedo()

        #expect(vm.draftTiles?.first?.size == .medium)
        #expect(vm.canRedo == false)
        #expect(vm.canUndo == true)
    }

    @Test
    func performRedo_afterUndoingReorder_reappliesTheOrder() {
        let vm = makeViewModel()
        let tileA = makeTile(entityId: "light.a")
        let tileB = makeTile(entityId: "light.b")
        vm.enterEditMode(seed: [(tileA, "light.a"), (tileB, "light.b")])
        vm.recordReorderUndo(previousOrder: [tileA.id, tileB.id])
        vm.applyReorder([tileB, tileA])
        vm.performUndo()

        vm.performRedo()

        #expect(vm.draftTiles?.map(\.id) == [tileB.id, tileA.id])
    }

    @Test
    func newEdit_afterUndo_clearsRedoStack() {
        let vm = makeViewModel()
        let tile = makeTile(entityId: "light.a", size: .small)
        vm.enterEditMode(seed: [(tile, "light.a")])
        vm.resizeTile(tile, to: .medium)
        vm.performUndo()
        #expect(vm.canRedo == true)

        vm.resizeTile(tile, to: .large)

        #expect(vm.canRedo == false)
    }

    @Test
    func undoRedo_roundTrip_isLossless() {
        let vm = makeViewModel()
        let tile = makeTile(entityId: "light.a", size: .small)
        vm.enterEditMode(seed: [(tile, "light.a")])
        vm.resizeTile(tile, to: .medium)

        vm.performUndo()
        vm.performRedo()
        vm.performUndo()

        #expect(vm.draftTiles?.first?.size == .small)
        #expect(vm.canUndo == false)
        #expect(vm.canRedo == true)
    }

    // MARK: - Remove From Home

    @Test
    func removeFromHome_delegatesToRepository() {
        let vm = makeViewModel()
        vm.removeFromHome(entityId: "light.lamp")

        #expect(tileRepo.removeFromHomeCalls == ["light.lamp"])
    }

    // MARK: - Open in Home Assistant

    @Test
    func openEntityInHA_withDeviceId_opensDevicePage() async {
        let vm = makeViewModel()
        vm.openEntityInHA(entityId: "light.lamp", deviceId: "device123")

        #expect(vm.haWebViewPresenter.url?.path.contains("config/devices/device/device123") == true)
        await vm.haWebViewPresenter.presentationTask?.value
        #expect(vm.haWebViewPresenter.isPresented == true)
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
        let retrier = SpyCuratedConnectionRetrier()
        let vm = makeViewModel(connectionRetrier: retrier)

        vm.retrySyncAndReload()

        #expect(vm.isRetrying == true)
        #expect(retrier.retryCallCount == 1)
    }
}

@MainActor
private final class SpyCuratedConnectionRetrier: ConnectionRetrying {
    var retryCallCount = 0
    func retryConnection() { retryCallCount += 1 }
}
