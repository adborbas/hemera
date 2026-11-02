import Foundation

struct AppStoreRelease: Equatable {
    let version: String
    let releaseDate: Date
    let minimumOsVersion: String
    let trackId: Int
}

@MainActor
protocol AppStoreLookup {
    /// `nil` when the App Store has no release of this app.
    func latestRelease() async throws -> AppStoreRelease?
}

struct NoAppStoreRelease: AppStoreLookup {
    func latestRelease() async throws -> AppStoreRelease? { nil }
}

#if DEBUG
struct FakeAppStoreLookup: AppStoreLookup {
    func latestRelease() async throws -> AppStoreRelease? {
        AppStoreRelease(
            version: "9999",
            releaseDate: .now.addingTimeInterval(-30 * 24 * 60 * 60),
            minimumOsVersion: "18.0",
            trackId: 6761782149
        )
    }
}
#endif
