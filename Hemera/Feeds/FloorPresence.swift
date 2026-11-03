import Foundation
import SwiftData

/// Whether Home Assistant has any floors, which decides if Areas offers its floor-grouping menu.
@Observable
@MainActor
final class FloorPresence {

    private(set) var hasFloors = false

    private let context: ModelContext
    @ObservationIgnored private nonisolated(unsafe) var saveObserver: (any NSObjectProtocol)?

    init(context: ModelContext) {
        self.context = context
        reload()

        // Only inserts and deletes can change whether floors exist.
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: context,
            queue: nil
        ) { [weak self] notification in
            let keys = [ModelContext.NotificationKey.insertedIdentifiers, .deletedIdentifiers]
            let membershipChanged = keys.contains { key in
                !((notification.userInfo?[key.rawValue] as? [PersistentIdentifier]) ?? []).isEmpty
            }
            guard membershipChanged else { return }
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    deinit {
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
        }
    }

    private func reload() {
        hasFloors = ((try? context.fetchCount(FetchDescriptor<FloorEntity>())) ?? 0) > 0
    }
}
