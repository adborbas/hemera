import HemeraLog

/// Marker protocol for production controllers that wrap `HAServiceCalling`.
///
/// Provides a default `performServiceCall` implementation that handles
/// the try-catch, logging, and user-facing error notification pattern
/// shared by all per-domain controllers.
@MainActor
protocol ServiceCallErrorHandling {
    var errorNotifier: ErrorNotifier { get }
}

extension ServiceCallErrorHandling {
    /// Executes a service call operation with standardized error handling.
    ///
    /// On failure: logs the error and shows a user-facing toast via `ErrorNotifier`.
    func performServiceCall(_ errorMessage: String, _ operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch {
            Log.error(errorMessage, cause: error)
            errorNotifier.showServiceCallError(error)
        }
    }
}
