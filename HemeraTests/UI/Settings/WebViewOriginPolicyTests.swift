import Foundation
import Testing
@testable import Hemera

@MainActor
struct WebViewOriginPolicyTests {

    private let serverURL = URL(string: "http://ha.local:8123/config/entities/entity/light.lamp")!
    private var policy: WebViewOriginPolicy { WebViewOriginPolicy(serverURL: serverURL) }

    // MARK: - Frame origins

    @Test
    func allowsOrigin_sameSchemeHostAndPort_isTrue() {
        #expect(policy.allows(scheme: "http", host: "ha.local", port: 8123))
    }

    /**
     The whole point: a page that is not the server must never be handed a token, and the
     frontend reaches pages like `home-assistant.io` by a single link tap.
    */
    @Test
    func allowsOrigin_differentHost_isFalse() {
        #expect(!policy.allows(scheme: "http", host: "evil.example", port: 8123))
    }

    /// A proxy redirecting the document to https is the same server; refusing it blanks the page.
    @Test
    func allowsOrigin_httpsUpgradeOfTheSameAddress_isTrue() {
        #expect(policy.allows(scheme: "https", host: "ha.local", port: 8123))
        #expect(WebViewOriginPolicy(serverURL: URL(string: "http://ha.local")!)
            .allows(scheme: "https", host: "ha.local", port: 443))
    }

    /// Upgrading is the same server; dropping to plain http is a different one and gets no token.
    @Test
    func allowsOrigin_httpDowngradeOfAnHTTPSServer_isFalse() {
        let secure = WebViewOriginPolicy(serverURL: URL(string: "https://ha.local:8123")!)

        #expect(!secure.allows(scheme: "http", host: "ha.local", port: 8123))
        #expect(!secure.allows(scheme: "http", host: "ha.local", port: 80))
    }

    @Test
    func allowsOrigin_differentPort_isFalse() {
        #expect(!policy.allows(scheme: "http", host: "ha.local", port: 9000))
    }

    @Test
    func allowsOrigin_hostDifferingOnlyByCase_isTrue() {
        #expect(policy.allows(scheme: "HTTP", host: "HA.Local", port: 8123))
    }

    @Test
    func allowsOrigin_zeroPort_matchesTheSchemeDefault() {
        let defaultPortPolicy = WebViewOriginPolicy(serverURL: URL(string: "https://ha.example.com")!)

        #expect(defaultPortPolicy.allows(scheme: "https", host: "ha.example.com", port: 0))
        #expect(defaultPortPolicy.allows(scheme: "https", host: "ha.example.com", port: 443))
        #expect(!defaultPortPolicy.allows(scheme: "https", host: "ha.example.com", port: 8123))
    }

    // MARK: - Navigation targets

    @Test
    func allowsURL_sameOrigin_isTrue() {
        #expect(policy.allows(URL(string: "http://ha.local:8123/lovelace/0")!))
    }

    @Test
    func allowsURL_httpsUpgradeOfTheSameAddress_isTrue() {
        #expect(policy.allows(URL(string: "https://ha.local:8123/lovelace/0")!))
    }

    @Test
    func allowsURL_offOriginOrNilOrNonHTTPScheme_isFalse() {
        #expect(!policy.allows(URL(string: "https://www.home-assistant.io/integrations/light/")!))
        #expect(!policy.allows(nil))
        #expect(!policy.allows(URL(string: "mailto:someone@ha.local")!))
        #expect(!policy.allows(URL(string: "javascript:alert(1)")!))
    }
}
