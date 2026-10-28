import Foundation
import HemeraLog

/// Errors from the Home Assistant REST API.
enum HARESTError: Error {
    case badResponse(URLResponse)
}

/// Abstraction for Home Assistant REST API operations.
protocol HARESTClienting: Sendable {
    func fetchVersion() async -> String?
}

/// Client for Home Assistant REST API calls.
///
/// Used for operations that aren't available via WebSocket.
actor HARESTClient: HARESTClienting {
    private let urlProvider: @Sendable () -> URL
    private let tokenProvider: @Sendable () async throws -> String

    init(
        urlProvider: @escaping @Sendable () -> URL,
        tokenProvider: @escaping @Sendable () async throws -> String
    ) {
        self.urlProvider = urlProvider
        self.tokenProvider = tokenProvider
    }

    /// Fetches the Home Assistant server version.
    func fetchVersion() async -> String? {
        do {
            let token = try await tokenProvider()
            var request = URLRequest(url: urlProvider().appendingPathComponent("/api/config"))
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }

            struct HAConfig: Decodable { let version: String }
            return try? JSONDecoder().decode(HAConfig.self, from: data).version
        } catch {
            Log.warning("Failed to fetch HA version", cause: error)
            return nil
        }
    }
}
