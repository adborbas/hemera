import Foundation
import SwiftData

/// Bundles all session-scoped dependencies created when a session starts.
///
/// All properties are non-optional — a `Session` is always complete.
/// Created atomically by `SessionManager`, stored as `ServiceLocator.shared.session`,
/// and nilled out on session teardown.
@MainActor
struct Session {
    let container: ModelContainer
    let connectionStatusProvider: any ConnectionStatusProviding
    let homeTileRepository: any HomeTileRepository
    let viewModelFactory: ViewModelFactory
    let mainContext: ModelContext
    let restClient: any HARESTClienting
    let errorNotifier: ErrorNotifier
    let resync: () async -> Void
}
