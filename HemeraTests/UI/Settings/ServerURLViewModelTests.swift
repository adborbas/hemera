import Foundation
import Testing
@testable import Hemera

@MainActor
struct ServerURLViewModelTests {

    private let current = URL(string: "http://homeassistant.local:8123")!

    // MARK: - Saving

    @Test func save_whenAccepted_recordsNewURLAndDismisses() async {
        let spy = SpyURLChanger()
        let viewModel = ServerURLViewModel(currentURL: current, urlChanger: spy)
        viewModel.urlText = "http://box.tailnet.ts.net:8123"

        await viewModel.save()

        #expect(spy.changeCalls == [URL(string: "http://box.tailnet.ts.net:8123")!])
        #expect(viewModel.didSave)
        #expect(viewModel.errorMessage == nil)
    }

    /**
     An address that reaches a *different* Home Assistant must cost the user nothing. HA answers
     an unknown refresh token with `invalid_grant`, which the logout path treats as an expired
     session — that would revoke the still-valid token and wipe the Keychain over a typo.
    */
    @Test func save_whenAddressServesDifferentInstance_doesNotSaveAndKeepsSession() async {
        let spy = SpyURLChanger()
        spy.result = .failure(AuthError.differentServer)
        let viewModel = ServerURLViewModel(currentURL: current, urlChanger: spy)
        viewModel.urlText = "http://someone-elses-ha.example.com:8123"

        await viewModel.save()

        #expect(!viewModel.didSave)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func save_whenAddressUnreachable_reportsReachabilityNotExpiry() async {
        let spy = SpyURLChanger()
        spy.result = .failure(AuthError.serverUnreachable)
        let viewModel = ServerURLViewModel(currentURL: current, urlChanger: spy)
        viewModel.urlText = "http://192.168.1.5:8123"

        await viewModel.save()

        #expect(!viewModel.didSave)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Normalisation

    /// LAN and VPN addresses are typically typed without a scheme.
    @Test func save_withSchemelessHost_defaultsToHTTP() async {
        let spy = SpyURLChanger()
        let viewModel = ServerURLViewModel(currentURL: current, urlChanger: spy)
        viewModel.urlText = "192.168.1.5:8123"

        await viewModel.save()

        #expect(spy.changeCalls == [URL(string: "http://192.168.1.5:8123")!])
    }

    /**
     How Home Assistant is exposed is the user's configuration decision, not Hemera's. A plain
     HTTP address (a Tailscale or WireGuard address is encrypted below HTTP) must be accepted
     without objection — this fails if a scheme restriction is ever reintroduced.
    */
    @Test func save_withPlainHTTPAddress_isAccepted() async {
        let spy = SpyURLChanger()
        let viewModel = ServerURLViewModel(currentURL: current, urlChanger: spy)
        viewModel.urlText = "http://box.tailnet.ts.net:8123"

        await viewModel.save()

        #expect(spy.changeCalls.count == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func save_withMalformedInput_reportsInvalidAndDoesNotCallChanger() async {
        let spy = SpyURLChanger()
        let viewModel = ServerURLViewModel(currentURL: current, urlChanger: spy)
        viewModel.urlText = "   "

        await viewModel.save()

        #expect(spy.changeCalls.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - canSave

    @Test func canSave_withUnchangedURL_isFalse() {
        let viewModel = ServerURLViewModel(currentURL: current, urlChanger: SpyURLChanger())
        #expect(!viewModel.canSave)
    }

    /**
     The stored URL may carry a trailing slash that the normalised typed value never has.
     Comparing raw-to-normalised made an untouched field look edited, so Save was tappable
     and would "change" the address to the one already in use.
    */
    @Test func canSave_whenStoredURLHasTrailingSlash_isFalseForSameAddress() {
        let viewModel = ServerURLViewModel(
            currentURL: URL(string: "http://homeassistant.local:8123/")!,
            urlChanger: SpyURLChanger()
        )
        #expect(!viewModel.canSave)
    }

    @Test func canSave_withChangedURL_isTrue() {
        let viewModel = ServerURLViewModel(currentURL: current, urlChanger: SpyURLChanger())
        viewModel.urlText = "http://192.168.1.5:8123"
        #expect(viewModel.canSave)
    }
}

// MARK: - Spy

@MainActor
private final class SpyURLChanger: ServerURLChanging {
    var changeCalls: [URL] = []
    var result: Result<Void, Error> = .success(())

    func changeServerURL(to url: URL) async throws {
        changeCalls.append(url)
        try result.get()
    }
}
