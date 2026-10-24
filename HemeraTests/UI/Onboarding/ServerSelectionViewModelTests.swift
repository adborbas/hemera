import Foundation
import Testing
@testable import Hemera

@MainActor
struct ServerSelectionViewModelTests {

    // MARK: - Discovery

    @Test
    func startDiscovery_startsScanning() {
        let viewModel = makeViewModel()
        viewModel.startDiscovery()
        #expect(viewModel.discovery.isScanning == true)
    }

    @Test
    func stopDiscovery_stopsScanning() {
        let viewModel = makeViewModel()
        viewModel.startDiscovery()
        viewModel.stopDiscovery()
        #expect(viewModel.discovery.isScanning == false)
    }

    // MARK: - Manual URL Validation

    @Test
    func connectManual_withEmptyURL_setsErrorMessageAndReturnsFalse() async {
        let viewModel = makeViewModel()
        viewModel.manualURL = ""
        let result = await viewModel.connectManual()
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func connectManual_withInvalidURL_setsErrorMessageAndReturnsFalse() async {
        let viewModel = makeViewModel()
        viewModel.manualURL = "not a valid url :///"
        let result = await viewModel.connectManual()
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func connectManual_withValidHTTPURL_showsHTTPWarningAndReturnsTrue() async {
        let viewModel = makeViewModel()
        viewModel.manualURL = "http://192.168.1.100:8123"
        let result = await viewModel.connectManual()
        #expect(result == true)
        #expect(viewModel.showHTTPWarning == true)
        #expect(viewModel.pendingHTTPURL != nil)
    }

    @Test
    func connectManual_withValidHTTPSURL_startsOAuthAndReturnsTrue() async {
        let viewModel = makeViewModel()
        viewModel.manualURL = "https://ha.example.com:8123"
        let result = await viewModel.connectManual()
        #expect(result == true)
        #expect(viewModel.isConnecting == true)
        #expect(viewModel.showHTTPWarning == false)
    }

    @Test
    func connectManual_prependsHTTPIfNoScheme_returnsTrue() async {
        let viewModel = makeViewModel()
        viewModel.manualURL = "192.168.1.100:8123"
        let result = await viewModel.connectManual()
        #expect(result == true)
        #expect(viewModel.showHTTPWarning == true)
    }

    // MARK: - HTTP Warning

    @Test
    func connect_withHTTPURL_showsWarning() async {
        let viewModel = makeViewModel()
        let url = URL(string: "http://192.168.1.100:8123")!
        await viewModel.connect(to: url)
        #expect(viewModel.showHTTPWarning == true)
        #expect(viewModel.pendingHTTPURL == url)
    }

    @Test
    func connect_withHTTPSURL_doesNotShowWarning() async {
        let viewModel = makeViewModel()
        let url = URL(string: "https://ha.example.com:8123")!
        await viewModel.connect(to: url)
        #expect(viewModel.showHTTPWarning == false)
        #expect(viewModel.isConnecting == true)
    }

    @Test
    func confirmHTTPConnection_startsOAuthWithPendingURL() async {
        let viewModel = makeViewModel()
        let url = URL(string: "http://192.168.1.100:8123")!
        await viewModel.connect(to: url)

        await viewModel.confirmHTTPConnection()

        #expect(viewModel.isConnecting == true)
        #expect(viewModel.pendingHTTPURL == nil)
    }

    @Test
    func cancelHTTPWarning_clearsPendingURL() async {
        let viewModel = makeViewModel()
        let url = URL(string: "http://192.168.1.100:8123")!
        await viewModel.connect(to: url)

        viewModel.cancelHTTPWarning()

        #expect(viewModel.pendingHTTPURL == nil)
    }

    // MARK: - OAuth Callback Error Surfacing

    @Test
    func handleOAuthCallback_whenCallbackFails_setsErrorMessageAndDoesNotAuthenticate() async {
        let authManager = MockAuthManager()
        let viewModel = ServerSelectionViewModel(authManager: authManager, serverProbe: MockServerProbe())
        let serverURL = URL(string: "https://ha.example.com:8123")!
        let session = OAuthFlowManager.AuthSession(
            authorizeURL: serverURL,
            redirectURI: "https://ha.example.com:8123/hemera_callback",
            state: "expected-state",
            clientId: serverURL.absoluteString,
            serverURL: serverURL
        )
        // Callback carries a mismatched state, so handleCallback throws before any token exchange.
        let callbackURL = URL(string: "https://ha.example.com:8123/hemera_callback?state=wrong&code=abc")!

        await viewModel.handleOAuthCallback(url: callbackURL, session: session)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isConnecting == false)
        #expect(authManager.didAuthenticateCallCount == 0)
    }

    @Test
    func connectManual_withCredentialsInURL_reportsFailureAndSetsError() async {
        /**
         The URL passes field validation but OAuth preparation rejects the embedded
         credentials. The screen keeps focus in the field on a false return, so reporting
         success here would leave an unexplained error with the cursor gone.
        */
        let viewModel = makeViewModel()
        viewModel.manualURL = "https://user:pass@ha.example.com"
        let result = await viewModel.connectManual()
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.authSession == nil)
    }

    @Test
    func prepareManualEntry_clearsStaleErrorMessage() {
        let viewModel = makeViewModel()
        viewModel.errorMessage = "stale error"
        viewModel.prepareManualEntry()
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func startOAuth_clearsPreviousErrorMessage() async {
        let viewModel = makeViewModel()
        viewModel.errorMessage = "stale error"
        await viewModel.startOAuth(url: URL(string: "https://ha.example.com:8123")!)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Address Verification

    /**
     Preparing OAuth is pure string work, so without a probe an unreachable address opens a
     sign-in sheet that silently never loads. These pin the user-visible contract: no sheet,
     and a reason to act on.
    */

    @Test
    func startOAuth_whenAddressUnreachable_setsErrorAndOpensNoSession() async {
        let viewModel = makeViewModel(probeError: AuthError.serverUnreachable)

        await viewModel.startOAuth(url: URL(string: "https://notahost.invalid")!)

        #expect(viewModel.authSession == nil)
        #expect(viewModel.isConnecting == false)
        #expect(viewModel.errorMessage == ServerSelectionViewModel.Localization.unreachable)
    }

    @Test
    func startOAuth_whenAddressIsNotHomeAssistant_saysSoRatherThanUnreachable() async {
        // A reachable host that isn't Home Assistant needs a different fix from a network problem.
        let viewModel = makeViewModel(probeError: AuthError.notHomeAssistant)

        await viewModel.startOAuth(url: URL(string: "https://example.com")!)

        #expect(viewModel.authSession == nil)
        #expect(viewModel.errorMessage == ServerSelectionViewModel.Localization.notHomeAssistant)
    }

    @Test
    func connectManual_whenProbeFails_reportsFailureSoFocusReturnsToTheField() async {
        let viewModel = makeViewModel(probeError: AuthError.serverUnreachable)
        viewModel.manualURL = "https://notahost.invalid"

        let result = await viewModel.connectManual()

        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func confirmHTTPConnection_whenProbeFails_setsErrorAndOpensNoSession() async {
        // The HTTP warning is consented to before the probe runs, so its failure has to surface too.
        let viewModel = makeViewModel(probeError: AuthError.serverUnreachable)
        await viewModel.connect(to: URL(string: "http://192.168.1.100:8123")!)

        await viewModel.confirmHTTPConnection()

        #expect(viewModel.authSession == nil)
        #expect(viewModel.isConnecting == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func authSessionFailed_dismissesSheetAndExplainsWhy() async {
        // The sign-in page can still fail to load after a passing probe — a TLS error, say.
        let viewModel = makeViewModel()
        await viewModel.startOAuth(url: URL(string: "https://ha.example.com:8123")!)
        #expect(viewModel.authSession != nil)

        viewModel.authSessionFailed()

        #expect(viewModel.authSession == nil)
        #expect(viewModel.isConnecting == false)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Auth Cancellation

    @Test
    func cancelAuth_clearsSessionAndStopsConnecting() async {
        let viewModel = makeViewModel()
        let url = URL(string: "https://ha.example.com:8123")!
        await viewModel.connect(to: url)
        #expect(viewModel.isConnecting == true)

        viewModel.cancelAuth()

        #expect(viewModel.authSession == nil)
        #expect(viewModel.isConnecting == false)
    }
}

// MARK: - Helpers

private extension ServerSelectionViewModelTests {

    func makeViewModel(probeError: (any Error)? = nil) -> ServerSelectionViewModel {
        ServerSelectionViewModel(
            authManager: MockAuthManager(),
            serverProbe: MockServerProbe(throwing: probeError)
        )
    }
}
