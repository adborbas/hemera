import Foundation
import SwiftData

/// Home Assistant's floors and areas, refetched when any are added or removed.
@Observable
@MainActor
final class FloorsAndAreas {

    /// Decides if Areas offers its floor-grouping menu.
    private(set) var hasFloors = false
    private(set) var areas: [AreaEntity] = []

    private let context: ModelContext
    @ObservationIgnored private nonisolated(unsafe) var saveObserver: (any NSObjectProtocol)?

    init(context: ModelContext) {
        self.context = context
        reload()

        // Only inserts and deletes can change which floors and areas exist.
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
        areas = (try? context.fetch(FetchDescriptor<AreaEntity>())) ?? []
    }
}
