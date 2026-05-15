import Foundation
import HAKit
import HemeraLog

/// Protocol for calling Home Assistant services via WebSocket.
@MainActor
protocol HAServiceCalling {
    /// Calls a Home Assistant service.
    ///
    /// - Parameters:
    ///   - domain: The service domain (e.g., "light", "cover", "switch")
    ///   - service: The service name (e.g., "turn_on", "turn_off", "toggle")
    ///   - data: Additional service data (e.g., ["entity_id": "light.living_room"])
    func callService(domain: String, service: String, data: [String: Any]) async throws
}

/// Default implementation using HAKit WebSocket connection.
@MainActor
final class HAServiceCaller: HAServiceCalling {
    private let connection: HAConnection

    init(connection: HAConnection) {
        self.connection = connection
    }

    func callService(domain: String, service: String, data: [String: Any]) async throws {
        let request = HATypedRequest<HAResponseVoid>.callService(
            domain: HAServicesDomain(stringLiteral: domain),
            service: HAServicesService(stringLiteral: service),
            data: data
        )
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HAResponseVoid, Error>) in
            connection.send(request) { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension HAServiceCalling {
    /// Calls a service for a specific entity.
    func callService(domain: String, service: String, entityId: String) async throws {
        try await callService(domain: domain, service: service, data: ["entity_id": entityId])
    }

    /// Calls a service with entity ID and additional data.
    func callService(
        domain: String,
        service: String,
        entityId: String,
        extraData: [String: Any]
    ) async throws {
        var data: [String: Any] = ["entity_id": entityId]
        data.merge(extraData) { _, new in new }
        try await callService(domain: domain, service: service, data: data)
    }
}

// MARK: - Error Classification

extension HAServiceCaller {
    enum ServiceCallErrorKind: Equatable {
        case connection
        case server
    }

    /// Classifies a service call error based on the underlying HAKit error type.
    ///
    /// - `.server`: The HA server explicitly rejected the request (`HAError.external`).
    /// - `.connection`: Network or transport-level failure (all other errors).
    static func classifyError(_ error: Error) -> ServiceCallErrorKind {
        if let haError = error as? HAError, case .external = haError {
            return .server
        }
        return .connection
    }
}
