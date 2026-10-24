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
        let viewModel = makeViewModel(probe: MockServerProbe(answering: ["http"]))
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
    func connectManual_withNoScheme_prefersHTTPSAndNeverWarns() async {
        // The whole point of resolving: a bare host that serves https must not nag about http.
        let viewModel = makeViewModel(probe: MockServerProbe(answering: ["https", "http"]))
        viewModel.manualURL = "192.168.1.100:8123"

        let result = await viewModel.connectManual()

        #expect(result == true)
        #expect(viewModel.showHTTPWarning == false)
        #expect(viewModel.authSession?.serverURL.scheme == "https")
    }

    @Test
    func connectManual_withNoScheme_fallsBackToHTTPAndWarnsNamingTheAddress() async {
        let viewModel = makeViewModel(probe: MockServerProbe(answering: ["http"]))
        viewModel.manualURL = "192.168.1.100:8123"

        _ = await viewModel.connectManual()

        // Warning only once http is known to be the one that works, and it names what answered.
        #expect(viewModel.showHTTPWarning == true)
        #expect(viewModel.pendingHTTPURL?.absoluteString == "http://192.168.1.100:8123")
        #expect(viewModel.authSession == nil)
    }

    @Test
    func connectManual_withNoScheme_triesHTTPSFirstAndOnlyWaitsLongForTheLast() async {
        /**
         Order and patience are the contract: https is tried first so an address serving both
         is reached encrypted, and the guess that isn't last gets a short timeout so a hung
         port can't eat the whole attempt.
        */
        let probe = MockServerProbe(answering: [])
        let viewModel = makeViewModel(probe: probe)
        viewModel.manualURL = "192.168.1.100:8123"

        _ = await viewModel.connectManual()

        #expect(probe.probed.map { $0.url.scheme } == ["https", "http"])
        #expect(probe.probed.map(\.timeout) == [ServerProbe.speculative, ServerProbe.confirmed])
    }

    @Test
    func connectManual_withTypedScheme_neverTriesTheOther() async {
        // A named scheme is the user's instruction, not a hint — we must not connect elsewhere.
        let probe = MockServerProbe(answering: ["https"])
        let viewModel = makeViewModel(probe: probe)
        viewModel.manualURL = "http://192.168.1.100:8123"

        _ = await viewModel.connectManual()

        #expect(probe.probed.map { $0.url.scheme } == ["http"])
        #expect(viewModel.authSession == nil)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - HTTP Warning

    @Test
    func connect_withHTTPURL_showsWarning() async {
        let viewModel = makeViewModel(probe: MockServerProbe(answering: ["http"]))
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
        let viewModel = makeViewModel(probe: MockServerProbe(answering: ["http"]))
        let url = URL(string: "http://192.168.1.100:8123")!
        await viewModel.connect(to: url)

        await viewModel.confirmHTTPConnection()

        #expect(viewModel.isConnecting == true)
        #expect(viewModel.pendingHTTPURL == nil)
    }

    @Test
    func cancelHTTPWarning_clearsPendingURL() async {
        let viewModel = makeViewModel(probe: MockServerProbe(answering: ["http"]))
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
    func connect_clearsPreviousErrorMessage() async {
        let viewModel = makeViewModel()
        viewModel.errorMessage = "stale error"
        await viewModel.connect(to: URL(string: "https://ha.example.com:8123")!)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Address Verification

    /**
     Preparing OAuth is pure string work, so without a probe an unreachable address opens a
     sign-in sheet that silently never loads. These pin the user-visible contract: no sheet,
     and a reason to act on.
    */

    @Test
    func connect_whenAddressUnreachable_setsErrorAndOpensNoSession() async {
        let viewModel = makeViewModel(probe: .failing(AuthError.serverUnreachable))

        await viewModel.connect(to: URL(string: "https://notahost.invalid")!)

        #expect(viewModel.authSession == nil)
        #expect(viewModel.isConnecting == false)
        #expect(viewModel.errorMessage == ServerSelectionViewModel.Localization.unreachable)
    }

    @Test
    func connect_whenAddressIsNotHomeAssistant_saysSoRatherThanUnreachable() async {
        // A reachable host that isn't Home Assistant needs a different fix from a network problem.
        let viewModel = makeViewModel(probe: .failing(AuthError.notHomeAssistant))

        await viewModel.connect(to: URL(string: "https://example.com")!)

        #expect(viewModel.authSession == nil)
        #expect(viewModel.errorMessage == ServerSelectionViewModel.Localization.notHomeAssistant)
    }

    @Test
    func connectManual_whenProbeFails_reportsFailureSoFocusReturnsToTheField() async {
        let viewModel = makeViewModel(probe: .failing(AuthError.serverUnreachable))
        viewModel.manualURL = "https://notahost.invalid"

        let result = await viewModel.connectManual()

        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func confirmHTTPConnection_whenProbeFails_setsErrorAndOpensNoSession() async {
        // The HTTP warning is consented to before the probe runs, so its failure has to surface too.
        let viewModel = makeViewModel(probe: .failing(AuthError.serverUnreachable))
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
        await viewModel.connect(to: URL(string: "https://ha.example.com:8123")!)
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

    func makeViewModel(probe: MockServerProbe = MockServerProbe()) -> ServerSelectionViewModel {
        ServerSelectionViewModel(authManager: MockAuthManager(), serverProbe: probe)
    }
}
