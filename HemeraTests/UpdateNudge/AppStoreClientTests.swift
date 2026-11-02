import Foundation
import Testing
@testable import Hemera

@MainActor
struct AppStoreClientTests {

    /// Trimmed from a real lookup response; the extra fields prove unknown keys don't break decoding.
    @Test func decode_realLookupResponse_readsTheFieldsTheNudgeNeeds() throws {
        let json = """
        {"resultCount":1,"results":[{"version":"2.0","currentVersionReleaseDate":"2026-10-29T00:59:11Z",
        "minimumOsVersion":"18.0","trackId":6761782149,"bundleId":"com.adborbas.hemera.app",
        "trackName":"Hemera","price":0.0,"genres":["Utilities"],"releaseNotes":"Fixes"}]}
        """

        let release = try AppStoreClient.decode(Data(json.utf8))

        #expect(release == AppStoreRelease(
            version: "2.0",
            releaseDate: Date(timeIntervalSince1970: 1_793_235_551),
            minimumOsVersion: "18.0",
            trackId: 6761782149
        ))
    }

    /// An app that isn't on the App Store yet must read as "no release", not as a failure.
    @Test func decode_emptyResults_isNoRelease() throws {
        let release = try AppStoreClient.decode(Data(#"{"resultCount":0,"results":[]}"#.utf8))

        #expect(release == nil)
    }
}
