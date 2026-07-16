import Foundation
import Testing
@testable import Hemera

struct TokenClientTests {

    // MARK: - formEncode

    @Test
    func formEncode_escapesStructuralCharactersInValue() {
        let encoded = TokenClient.formEncode(["a": "x+y=z&w,v"])

        #expect(encoded == "a=x%2By%3Dz%26w%2Cv")
    }

    @Test
    func formEncode_escapesStructuralCharactersInKey() {
        let encoded = TokenClient.formEncode(["a+b": "c"])

        #expect(encoded == "a%2Bb=c")
    }

    @Test
    func formEncode_hexTokenRoundTripsUnchanged() {
        let encoded = TokenClient.formEncode(["refresh_token": "abcdef0123456789"])

        #expect(encoded == "refresh_token=abcdef0123456789")
    }

    @Test
    func formEncode_clientIdOriginURL_escapesSchemeSeparators() {
        let encoded = TokenClient.formEncode(["client_id": "https://home.example.com:8123"])

        #expect(encoded == "client_id=https%3A%2F%2Fhome.example.com%3A8123")
    }
}
