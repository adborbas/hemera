import Foundation
import StoreKit

struct AppStoreRelease: Equatable, Decodable {
    let version: String
    let releaseDate: Date
    let minimumOsVersion: String
    let trackId: Int

    private enum CodingKeys: String, CodingKey {
        case version, minimumOsVersion, trackId
        case releaseDate = "currentVersionReleaseDate"
    }
}

@MainActor
protocol AppStoreLookup {
    /// `nil` when the App Store has no release of this app.
    func latestRelease() async throws -> AppStoreRelease?
}

struct AppStoreClient: AppStoreLookup {
    private static let url = URL(string: "https://itunes.apple.com/lookup?bundleId=com.adborbas.hemera.app")!

    func latestRelease() async throws -> AppStoreRelease? {
        // Apple sends a ~24 h max-age, which would otherwise serve every daily check from the cache.
        let request = URLRequest(url: Self.url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try Self.decode(data)
    }

    static func decode(_ data: Data) throws -> AppStoreRelease? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LookupResponse.self, from: data).results.first
    }

    /// TestFlight reports `.sandbox` and Xcode installs `.xcode`, so only App Store downloads pass.
    static func isProductionBuild() async -> Bool {
        #if DEBUG
        return false
        #else
        guard case .verified(let transaction)? = try? await AppTransaction.shared else { return false }
        return transaction.environment == .production
        #endif
    }
}

private struct LookupResponse: Decodable {
    let results: [AppStoreRelease]
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
