import Foundation
import Testing
@testable import Hemera

@MainActor
struct ServerURLViewModelTests {

    private let current = URL(string: "http://homeassistant.local:8123")!
    private var editMode: ServerAddressMode { .edit(current: current) }

    // MARK: - Saving

    @Test func save_whenAccepted_recordsNewURLAndDismisses() async {
        let spy = SpyURLChanger()
        let viewModel = ServerURLViewModel(mode: editMode, urlChanger: spy)
        viewModel.text = "http://box.tailnet.ts.net:8123"

        let result = await viewModel.submit()

        #expect(spy.changeCalls == [URL(string: "http://box.tailnet.ts.net:8123")!])
        #expect(result)
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
        let viewModel = ServerURLViewModel(mode: editMode, urlChanger: spy)
        viewModel.text = "http://someone-elses-ha.example.com:8123"

        let result = await viewModel.submit()

        #expect(!result)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func save_whenAddressUnreachable_reportsReachabilityNotExpiry() async {
        let spy = SpyURLChanger()
        spy.result = .failure(AuthError.serverUnreachable)
        let viewModel = ServerURLViewModel(mode: editMode, urlChanger: spy)
        viewModel.text = "http://192.168.1.5:8123"

        let result = await viewModel.submit()

        #expect(!result)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Normalisation

    /**
     A scheme-less host is guessed as https. Settings cannot resolve the way onboarding does,
     so guessing http here would quietly move an encrypted session to cleartext; guessing
     https fails loudly instead, and the scheme can be typed to say otherwise.
    */
    @Test func save_withSchemelessHost_defaultsToHTTPS() async {
        let spy = SpyURLChanger()
        let viewModel = ServerURLViewModel(mode: editMode, urlChanger: spy)
        viewModel.text = "192.168.1.5:8123"

        _ = await viewModel.submit()

        #expect(spy.changeCalls == [URL(string: "https://192.168.1.5:8123")!])
    }

    /**
     How Home Assistant is exposed is the user's configuration decision, not Hemera's. A plain
     HTTP address (a Tailscale or WireGuard address is encrypted below HTTP) must be accepted
     without objection — this fails if a scheme restriction is ever reintroduced.
    */
    @Test func save_withPlainHTTPAddress_isAccepted() async {
        let spy = SpyURLChanger()
        let viewModel = ServerURLViewModel(mode: editMode, urlChanger: spy)
        viewModel.text = "http://box.tailnet.ts.net:8123"

        _ = await viewModel.submit()

        #expect(spy.changeCalls.count == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func save_withMalformedInput_reportsInvalidAndDoesNotCallChanger() async {
        let spy = SpyURLChanger()
        let viewModel = ServerURLViewModel(mode: editMode, urlChanger: spy)
        viewModel.text = "   "

        let result = await viewModel.submit()

        #expect(!result)
        #expect(spy.changeCalls.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - canSave

    @Test func canSubmit_withUnchangedURL_isFalse() {
        let viewModel = ServerURLViewModel(mode: editMode, urlChanger: SpyURLChanger())
        #expect(!viewModel.canSubmit)
    }

    /**
     The stored URL may carry a trailing slash that the normalised typed value never has.
     Comparing raw-to-normalised made an untouched field look edited, so Save was tappable
     and would "change" the address to the one already in use.
    */
    @Test func canSubmit_whenStoredURLHasTrailingSlash_isFalseForSameAddress() {
        let viewModel = ServerURLViewModel(
            mode: .edit(current: URL(string: "http://homeassistant.local:8123/")!),
            urlChanger: SpyURLChanger()
        )
        #expect(!viewModel.canSubmit)
    }

    @Test func canSubmit_withChangedURL_isTrue() {
        let viewModel = ServerURLViewModel(mode: editMode, urlChanger: SpyURLChanger())
        viewModel.text = "http://192.168.1.5:8123"
        #expect(viewModel.canSubmit)
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
