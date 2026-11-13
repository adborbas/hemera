import Foundation
import SwiftData
import Testing
import TileGridEngine
@testable import Hemera

@MainActor
struct OnboardingCoordinatorTests {

    private let connection = SpyServerConnection()
    private let authManager = MockAuthManager()
    private let router = SpyOnboardingRouter()
    private let tileRepository = MockHomeTileRepository()
    private let retrier = MockConnectionRetrier()
    private let clock = ManualSleep()
    private let home: CuratedHomeViewModel
    private let coordinator: OnboardingCoordinator

    init() throws {
        let container = try ModelContainer(for: HomeTile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        home = CuratedHomeViewModel(
            homeTileRepository: tileRepository,
            viewModelFactory: ViewModelFactory(context: container.mainContext, container: container),
            authManager: authManager,
            demoCoordinator: MockDemoCoordinator()
        )
        coordinator = OnboardingCoordinator(
            connection: connection,
            authManager: authManager,
            router: router,
            connectionRetrier: retrier,
            sleep: clock.sleep
        )
    }

    // MARK: - Page Order

    @Test
    func pages_areOrderedAsTheUserMeetsThem() {
        #expect(OnboardingCoordinator.Page.server < .manualAddress)
        #expect(OnboardingCoordinator.Page.manualAddress < .login)
        #expect(OnboardingCoordinator.Page.login < .home)
    }

    @Test
    func progress_ofEachPage() {
        #expect(OnboardingCoordinator.Page.server.progress == 1)
        #expect(OnboardingCoordinator.Page.manualAddress.progress == 1.5)
        #expect(OnboardingCoordinator.Page.login.progress == 2)
        #expect(OnboardingCoordinator.Page.home.progress == 3)
    }

    @Test
    func progress_home_fillsTheBar() {
        #expect(OnboardingCoordinator.Page.home.progress == Double(OnboardingCoordinator.stepCount))
    }

    // MARK: - Server

    @Test
    func init_startsOnServer() {
        #expect(coordinator.page == .server)
        #expect(coordinator.contentPage == .server)
        #expect(coordinator.progress == 1)
    }

    @Test
    func server_hidesBackAndBottomButton() {
        #expect(coordinator.canGoBack == false)
        #expect(coordinator.bottomButton == nil)
    }

    @Test
    func back_onServer_staysOnServer() {
        coordinator.back()
        #expect(coordinator.page == .server)
        #expect(connection.abandonConnectionCallCount == 0)
    }

    // MARK: - Manual Address

    @Test
    func enterAddressManually_movesForwardHalfAStep() {
        coordinator.enterAddressManually()
        #expect(coordinator.page == .manualAddress)
        #expect(coordinator.contentPage == .manualAddress)
        #expect(coordinator.progress == 1.5)
        #expect(coordinator.isForward)
        #expect(connection.prepareManualEntryCallCount == 1)
    }

    @Test
    func manualAddress_showsBack() {
        coordinator.enterAddressManually()
        #expect(coordinator.canGoBack)
    }

    @Test
    func back_onManualAddress_returnsToServerAndAbandonsConnection() {
        coordinator.enterAddressManually()
        coordinator.back()
        #expect(coordinator.page == .server)
        #expect(coordinator.contentPage == .server)
        #expect(coordinator.progress == 1)
        #expect(coordinator.isForward == false)
        #expect(connection.abandonConnectionCallCount == 1)
    }

    @Test
    func bottomButton_onManualAddress_isConnect() {
        coordinator.enterAddressManually()
        #expect(coordinator.bottomButton?.title == ServerAddressMode.initial.actionTitle)
    }

    @Test
    func bottomButton_onManualAddress_followsWhetherTheAddressCanBeSubmitted() {
        coordinator.enterAddressManually()
        connection.canSubmit = false
        #expect(coordinator.bottomButton?.isEnabled == false)
        connection.canSubmit = true
        #expect(coordinator.bottomButton?.isEnabled == true)
    }

    @Test
    func bottomButton_onManualAddress_loadsWhileConnecting() {
        coordinator.enterAddressManually()
        connection.isBusy = true
        #expect(coordinator.bottomButton?.isLoading == true)
    }

    @Test
    func bottomButtonTapped_onManualAddress_submitsTheAddress() async {
        coordinator.enterAddressManually()
        connection.canSubmit = true
        await coordinator.bottomButtonTapped()
        #expect(connection.submitCallCount == 1)
    }

    @Test
    func bottomButtonTapped_whenDisabled_doesNotSubmit() async {
        coordinator.enterAddressManually()
        connection.canSubmit = false
        await coordinator.bottomButtonTapped()
        #expect(connection.submitCallCount == 0)
    }

    // MARK: - Log In

    @Test
    func loginOpened_fromServer_movesBarToLoginAndKeepsTheList() {
        coordinator.loginOpened()
        #expect(coordinator.page == .login)
        #expect(coordinator.contentPage == .server)
        #expect(coordinator.progress == 2)
        #expect(coordinator.canGoBack == false)
        #expect(coordinator.bottomButton == nil)
    }

    @Test
    func loginOpened_fromManualAddress_movesBarToLoginAndKeepsTheAddressPage() {
        coordinator.enterAddressManually()
        coordinator.loginOpened()
        #expect(coordinator.page == .login)
        #expect(coordinator.contentPage == .manualAddress)
        #expect(coordinator.progress == 2)
        #expect(coordinator.bottomButton != nil)
    }

    @Test
    func loginCancelled_fromServer_returnsToServer() {
        coordinator.loginOpened()
        coordinator.loginCancelled()
        #expect(coordinator.page == .server)
        #expect(coordinator.progress == 1)
        #expect(connection.cancelAuthCallCount == 1)
    }

    @Test
    func loginCancelled_fromManualAddress_returnsToManualAddress() {
        coordinator.enterAddressManually()
        coordinator.loginOpened()
        coordinator.loginCancelled()
        #expect(coordinator.page == .manualAddress)
        #expect(coordinator.progress == 1.5)
        #expect(connection.cancelAuthCallCount == 1)
    }

    @Test
    func loginCancelled_whenNotLoggingIn_changesNothing() {
        coordinator.enterAddressManually()
        coordinator.loginCancelled()
        #expect(coordinator.page == .manualAddress)
        #expect(connection.cancelAuthCallCount == 0)
    }

    @Test
    func back_onLogin_cancelsLogin() {
        coordinator.enterAddressManually()
        coordinator.loginOpened()
        coordinator.back()
        #expect(coordinator.page == .manualAddress)
        #expect(connection.cancelAuthCallCount == 1)
        #expect(connection.abandonConnectionCallCount == 0)
    }

    @Test
    func loginOpened_twice_keepsThePageBehindTheSheet() {
        coordinator.enterAddressManually()
        coordinator.loginOpened()
        coordinator.loginOpened()
        coordinator.loginCancelled()
        #expect(coordinator.page == .manualAddress)
    }
}

// MARK: - Home

extension OnboardingCoordinatorTests {

    private func loggedInFromServer() {
        coordinator.loginOpened()
        coordinator.loggedIn(home: home)
    }

    private func seedTwoTiles() -> [Tile] {
        let tiles = [Tile(id: UUID(), title: "Lamp", size: .small), Tile(id: UUID(), title: "Blind", size: .small)]
        home.enterEditMode(seed: [(tiles[0], "light.lamp"), (tiles[1], "cover.blind")])
        return tiles
    }

    @Test
    func loggedIn_pushesTheHomeStepAndClosesTheSheet() {
        loggedInFromServer()
        #expect(coordinator.page == .home)
        #expect(coordinator.contentPage == .home)
        #expect(coordinator.progress == 3)
        #expect(coordinator.isForward)
        #expect(coordinator.home === home)
    }

    @Test
    func loggedIn_fromManualAddress_pushesTheHomeStep() {
        coordinator.enterAddressManually()
        coordinator.loginOpened()
        coordinator.loggedIn(home: home)
        #expect(coordinator.page == .home)
        #expect(coordinator.canGoBack)
    }

    /// Finishing before the sync would land on an empty Home that then fills on its own.
    @Test
    func bottomButton_onHome_isFinishAndWaitsForTheSync() {
        loggedInFromServer()
        #expect(coordinator.bottomButton?.title == "Finish")
        #expect(coordinator.bottomButton?.isEnabled == false)
        router.sessionSync = .succeeded
        #expect(coordinator.bottomButton?.isEnabled == true)
    }

    @Test
    func bottomButtonTapped_onHomeBeforeTheSync_staysOnTheStep() async {
        loggedInFromServer()
        await coordinator.bottomButtonTapped()
        #expect(router.navigations.isEmpty)
        #expect(tileRepository.commitLayoutCalls.isEmpty)
    }

    @Test
    func bottomButtonTapped_onHome_savesTheEditsAndOpensTheApp() async {
        loggedInFromServer()
        let tiles = seedTwoTiles()
        home.removeTile(tiles[0])
        home.resizeTile(tiles[1], to: .medium)
        router.sessionSync = .succeeded

        await coordinator.bottomButtonTapped()

        #expect(tileRepository.removeFromHomeCalls == ["light.lamp"])
        #expect(tileRepository.commitLayoutCalls.first?.map(\.entityId) == ["cover.blind"])
        #expect(tileRepository.commitLayoutCalls.first?.first?.size == .medium)
        #expect(router.navigations == [.authenticated])
        #expect(connection.submitCallCount == 0)
    }

    @Test
    func back_onHome_asksBeforeLoggingOut() {
        loggedInFromServer()
        coordinator.back()
        #expect(coordinator.isConfirmingLogOut)
        #expect(coordinator.page == .home)
        #expect(authManager.logoutCallCount == 0)
    }

    @Test
    func cancelLogOut_staysOnHome() {
        loggedInFromServer()
        coordinator.back()
        coordinator.cancelLogOut()
        #expect(coordinator.isConfirmingLogOut == false)
        #expect(coordinator.page == .home)
        #expect(authManager.logoutCallCount == 0)
    }

    @Test
    func logOut_logsOutAndStartsAgainOnServer() {
        coordinator.enterAddressManually()
        coordinator.loginOpened()
        coordinator.loggedIn(home: home)
        _ = seedTwoTiles()
        coordinator.back()

        coordinator.logOut()

        #expect(authManager.logoutCallCount == 1)
        #expect(coordinator.isConfirmingLogOut == false)
        #expect(coordinator.page == .server)
        #expect(coordinator.contentPage == .server)
        #expect(coordinator.progress == 1)
        #expect(coordinator.isForward == false)
        #expect(coordinator.home == nil)
        #expect(connection.cancelAuthCallCount == 1)
        #expect(connection.abandonConnectionCallCount == 1)
        #expect(tileRepository.commitLayoutCalls.isEmpty)
        #expect(router.navigations.isEmpty)
    }

    @Test
    func logOut_forgetsTheTypedAddress() {
        coordinator.enterAddressManually()
        connection.text = "homeassistant.local:8123"
        coordinator.loginOpened()
        coordinator.loggedIn(home: home)
        coordinator.back()

        coordinator.logOut()

        #expect(connection.text.isEmpty)
    }

    @Test
    func serverHost_namesTheLoggedInServer() {
        authManager.credentials = ServerCredentials(
            serverURL: URL(string: "https://ha.example.com:8123")!,
            accessToken: "token",
            refreshToken: "refresh",
            tokenExpiresAt: .distantFuture,
            clientId: "client"
        )
        #expect(coordinator.serverHost == "ha.example.com")
    }
}

// MARK: - Home States

extension OnboardingCoordinatorTests {

    @Test
    func homeState_beforeTheTimeout_isLoadingWithFinishDisabled() async {
        loggedInFromServer()
        await clock.settle()
        #expect(coordinator.homeState == .loading)
        #expect(coordinator.bottomButton?.isEnabled == false)
        #expect(clock.durations == [.seconds(15)])
    }

    @Test
    func homeState_fifteenSecondsWithoutASync_isFailedWithFinishDisabled() async {
        loggedInFromServer()
        await clock.elapse()
        #expect(coordinator.homeState == .failed)
        #expect(coordinator.bottomButton?.isEnabled == false)
    }

    /// A failed sync has nothing to show, so it must not wait out the timeout or count as loaded.
    @Test
    func homeState_afterAFailedSync_isFailedAtOnce() {
        loggedInFromServer()
        router.sessionSync = .failed
        #expect(coordinator.homeState == .failed)
        #expect(coordinator.bottomButton?.isEnabled == false)
    }

    @Test
    func retryConnection_retriesAndWaitsAgainUntilASyncSucceeds() async {
        loggedInFromServer()
        router.sessionSync = .failed
        await clock.elapse()

        coordinator.retryConnection()

        #expect(coordinator.homeState == .loading)
        #expect(retrier.retryCallCount == 1)
        await clock.settle()
        #expect(clock.durations == [.seconds(15), .seconds(15)])
        tileRepository.stubbedHasAnyHomeTile = true
        router.sessionSync = .succeeded
        #expect(coordinator.homeState == .loaded)
        #expect(coordinator.bottomButton?.isEnabled == true)
    }

    @Test
    func retryConnection_failingAgain_showsTheFailureAfterTheRestartedTimeout() async {
        loggedInFromServer()
        await clock.elapse()
        coordinator.retryConnection()
        #expect(coordinator.homeState == .loading)

        await clock.elapse()

        #expect(coordinator.homeState == .failed)
    }

    @Test
    func homeState_afterASuccessfulSyncWithTiles_isLoadedWithFinishEnabled() {
        loggedInFromServer()
        tileRepository.stubbedHasAnyHomeTile = true
        router.sessionSync = .succeeded
        #expect(coordinator.homeState == .loaded)
        #expect(coordinator.isHomeEmpty == false)
        #expect(coordinator.bottomButton == .init(title: "Finish", isEnabled: true, isLoading: false))
    }

    /// The steps after Home are skipped when there is nothing on it, so the bar must read as done.
    @Test
    func homeState_afterASuccessfulSyncWithNoTiles_isEmptyAndFinishesOnboarding() async {
        loggedInFromServer()
        router.sessionSync = .succeeded

        #expect(coordinator.homeState == .empty)
        #expect(coordinator.isHomeEmpty)
        #expect(coordinator.progress == Double(OnboardingCoordinator.stepCount))
        #expect(coordinator.bottomButton == .init(title: "Finish", isEnabled: true, isLoading: false))

        await coordinator.bottomButtonTapped()
        #expect(router.navigations == [.authenticated])
    }

    @Test
    func isHomeEmpty_beforeTheHomeStep_isFalse() {
        router.sessionSync = .succeeded
        #expect(coordinator.isHomeEmpty == false)
        #expect(coordinator.progress == 1)
    }

    @Test
    func logOut_stopsTheTimeout() async {
        loggedInFromServer()
        coordinator.back()
        coordinator.logOut()

        await clock.elapse()

        #expect(coordinator.homeState == .loading)
    }

    @Test
    func finish_stopsTheTimeout() async {
        loggedInFromServer()
        router.sessionSync = .succeeded
        await coordinator.bottomButtonTapped()
        router.sessionSync = .pending

        await clock.elapse()

        #expect(coordinator.homeState == .loading)
    }
}

// MARK: - Spy

/// Sleeps until the test says the time has passed.
@MainActor
private final class ManualSleep {
    private(set) var durations: [Duration] = []
    private var pending: [CheckedContinuation<Void, Never>] = []

    func sleep(_ duration: Duration) async throws {
        durations.append(duration)
        await withCheckedContinuation { pending.append($0) }
    }

    /// Lets started timers reach their sleep.
    func settle() async {
        try? await Task.sleep(for: .milliseconds(100))
    }

    func elapse() async {
        await settle()
        let ending = pending
        pending = []
        ending.forEach { $0.resume() }
        await settle()
    }
}

@MainActor
private final class SpyOnboardingRouter: OnboardingRouting {
    var sessionSync = AppRouter.SessionSync.pending
    var navigations: [AppRouter.Destination] = []

    func syncRetried() { sessionSync = .pending }

    func navigate(to destination: AppRouter.Destination) { navigations.append(destination) }
}

@Observable
@MainActor
private final class SpyServerConnection: OnboardingServerConnecting {
    var text = ""
    var mode: ServerAddressMode { .initial }
    var isBusy = false
    var canSubmit = false
    var errorMessage: String?

    var submitCallCount = 0
    var prepareManualEntryCallCount = 0
    var abandonConnectionCallCount = 0
    var cancelAuthCallCount = 0

    func submit() async -> Bool {
        submitCallCount += 1
        return true
    }

    func prepareManualEntry() { prepareManualEntryCallCount += 1 }
    func abandonConnection() { abandonConnectionCallCount += 1 }
    func cancelAuth() { cancelAuthCallCount += 1 }
}
