import Foundation
import Testing
@testable import Hemera

// MARK: - Candidates

@MainActor
struct ServerAddressCandidateTests {

    @Test
    func candidates_withoutScheme_offersHTTPSBeforeHTTP() {
        // Order is the security property: an address serving both must be reached encrypted.
        let urls = ServerAddress.candidates("homeassistant.local:8123").map(\.absoluteString)
        #expect(urls == ["https://homeassistant.local:8123", "http://homeassistant.local:8123"])
    }

    @Test
    func candidates_withScheme_offersOnlyWhatWasTyped() {
        // A typed scheme is an instruction — resolving past it would connect somewhere unasked.
        #expect(ServerAddress.candidates("http://10.0.0.5:8123").map(\.absoluteString) == ["http://10.0.0.5:8123"])
        #expect(ServerAddress.candidates("https://ha.example.com").map(\.absoluteString) == ["https://ha.example.com"])
    }

    @Test
    func candidates_withUnusableInput_offersNothing() {
        #expect(ServerAddress.candidates("").isEmpty)
        #expect(ServerAddress.candidates("   ").isEmpty)
        #expect(ServerAddress.candidates("ftp://ha.example.com").isEmpty)
    }
}
