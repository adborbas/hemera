import Foundation
@testable import Hemera

@MainActor
final class MockRESTClient: HARESTClienting {
    var stubbedVersion: String?
    var fetchVersionCallCount = 0

    nonisolated func fetchVersion() async -> String? {
        await MainActor.run {
            fetchVersionCallCount += 1
            return stubbedVersion
        }
    }

    nonisolated func fetchAreaMappings() async throws -> [AreaMapping] {
        []
    }
}
