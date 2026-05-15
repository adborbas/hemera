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
    func connectManual_withEmptyURL_setsErrorMessageAndReturnsFalse() {
        let viewModel = makeViewModel()
        viewModel.manualURL = ""
        let result = viewModel.connectManual()
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func connectManual_withInvalidURL_setsErrorMessageAndReturnsFalse() {
        let viewModel = makeViewModel()
        viewModel.manualURL = "not a valid url :///"
        let result = viewModel.connectManual()
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func connectManual_withValidHTTPURL_showsHTTPWarningAndReturnsTrue() {
        let viewModel = makeViewModel()
        viewModel.manualURL = "http://192.168.1.100:8123"
        let result = viewModel.connectManual()
        #expect(result == true)
        #expect(viewModel.showHTTPWarning == true)
        #expect(viewModel.pendingHTTPURL != nil)
    }

    @Test
    func connectManual_withValidHTTPSURL_startsOAuthAndReturnsTrue() {
        let viewModel = makeViewModel()
        viewModel.manualURL = "https://ha.example.com:8123"
        let result = viewModel.connectManual()
        #expect(result == true)
        #expect(viewModel.isConnecting == true)
        #expect(viewModel.showHTTPWarning == false)
    }

    @Test
    func connectManual_prependsHTTPIfNoScheme_returnsTrue() {
        let viewModel = makeViewModel()
        viewModel.manualURL = "192.168.1.100:8123"
        let result = viewModel.connectManual()
        #expect(result == true)
        #expect(viewModel.showHTTPWarning == true)
    }

    // MARK: - HTTP Warning

    @Test
    func connect_withHTTPURL_showsWarning() {
        let viewModel = makeViewModel()
        let url = URL(string: "http://192.168.1.100:8123")!
        viewModel.connect(to: url)
        #expect(viewModel.showHTTPWarning == true)
        #expect(viewModel.pendingHTTPURL == url)
    }

    @Test
    func connect_withHTTPSURL_doesNotShowWarning() {
        let viewModel = makeViewModel()
        let url = URL(string: "https://ha.example.com:8123")!
        viewModel.connect(to: url)
        #expect(viewModel.showHTTPWarning == false)
        #expect(viewModel.isConnecting == true)
    }

    @Test
    func confirmHTTPConnection_startsOAuthWithPendingURL() {
        let viewModel = makeViewModel()
        let url = URL(string: "http://192.168.1.100:8123")!
        viewModel.connect(to: url)

        viewModel.confirmHTTPConnection()

        #expect(viewModel.isConnecting == true)
        #expect(viewModel.pendingHTTPURL == nil)
    }

    @Test
    func cancelHTTPWarning_clearsPendingURL() {
        let viewModel = makeViewModel()
        let url = URL(string: "http://192.168.1.100:8123")!
        viewModel.connect(to: url)

        viewModel.cancelHTTPWarning()

        #expect(viewModel.pendingHTTPURL == nil)
    }

    // MARK: - Auth Cancellation

    @Test
    func cancelAuth_clearsSessionAndStopsConnecting() {
        let viewModel = makeViewModel()
        let url = URL(string: "https://ha.example.com:8123")!
        viewModel.connect(to: url)
        #expect(viewModel.isConnecting == true)

        viewModel.cancelAuth()

        #expect(viewModel.authSession == nil)
        #expect(viewModel.isConnecting == false)
    }
}

// MARK: - Helpers

private extension ServerSelectionViewModelTests {

    func makeViewModel() -> ServerSelectionViewModel {
        ServerSelectionViewModel(authManager: MockAuthManager())
    }
}
