import Foundation
import Testing
@testable import Hemera

@MainActor
struct OnboardingCoordinatorTests {

    private let connection = SpyServerConnection()
    private let coordinator: OnboardingCoordinator

    init() {
        coordinator = OnboardingCoordinator(connection: connection)
    }

    // MARK: - Page Order

    @Test
    func pages_areOrderedAsTheUserMeetsThem() {
        #expect(OnboardingCoordinator.Page.server < .manualAddress)
        #expect(OnboardingCoordinator.Page.manualAddress < .login)
    }

    @Test
    func progress_ofEachPage() {
        #expect(OnboardingCoordinator.Page.server.progress == 1)
        #expect(OnboardingCoordinator.Page.manualAddress.progress == 1.5)
        #expect(OnboardingCoordinator.Page.login.progress == 2)
    }

    @Test
    func progress_login_fillsTheBar() {
        #expect(OnboardingCoordinator.Page.login.progress == Double(OnboardingCoordinator.stepCount))
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

// MARK: - Spy

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
