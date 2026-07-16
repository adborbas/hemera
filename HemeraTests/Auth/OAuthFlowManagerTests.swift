import Foundation
import Testing
@testable import Hemera

struct OAuthFlowManagerTests {

    // MARK: - No Base Path

    @Test
    func prepare_withNoBasePath_buildsRootLevelURLs() throws {
        let session = try OAuthFlowManager().prepare(serverURL: URL(string: "https://ha.example.com:8123")!)

        #expect(session.redirectURI == "https://ha.example.com:8123/hemera_callback")

        let authComponents = URLComponents(url: session.authorizeURL, resolvingAgainstBaseURL: false)!
        #expect(authComponents.path == "/auth/authorize")
        #expect(redirectURI(in: authComponents) == "https://ha.example.com:8123/hemera_callback")
    }

    // MARK: - Base Path

    @Test
    func prepare_withBasePath_preservesBasePath() throws {
        let session = try OAuthFlowManager().prepare(serverURL: URL(string: "https://example.com/ha")!)

        #expect(session.redirectURI == "https://example.com/ha/hemera_callback")

        let authComponents = URLComponents(url: session.authorizeURL, resolvingAgainstBaseURL: false)!
        #expect(authComponents.path == "/ha/auth/authorize")
        #expect(redirectURI(in: authComponents) == "https://example.com/ha/hemera_callback")
    }

    @Test
    func prepare_withTrailingSlash_doesNotDoubleSlash() throws {
        let session = try OAuthFlowManager().prepare(serverURL: URL(string: "https://example.com/ha/")!)

        #expect(session.redirectURI == "https://example.com/ha/hemera_callback")

        let authComponents = URLComponents(url: session.authorizeURL, resolvingAgainstBaseURL: false)!
        #expect(authComponents.path == "/ha/auth/authorize")
    }
}

// MARK: - Helpers

private extension OAuthFlowManagerTests {
    func redirectURI(in components: URLComponents) -> String? {
        components.queryItems?.first { $0.name == "redirect_uri" }?.value
    }
}
