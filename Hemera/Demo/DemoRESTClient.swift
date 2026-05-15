import Foundation

/// Stub REST client for demo mode — no real server to query.
final class DemoRESTClient: HARESTClienting {
    func fetchVersion() async -> String? { nil }
    func fetchAreaMappings() async throws -> [AreaMapping] { [] }
}
