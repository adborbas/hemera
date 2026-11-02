import Foundation
import SwiftData

/// Every area in Home Assistant order, for the pinned-area feeds, and whether any floors exist.
@Observable
@MainActor
final class AreaList {

    private(set) var areas: [AreaEntity] = []
    private(set) var hasFloors = false

    private var areasById: [String: AreaEntity] = [:]
    private let context: ModelContext
    @ObservationIgnored private nonisolated(unsafe) var saveObserver: (any NSObjectProtocol)?

    init(context: ModelContext) {
        self.context = context
        reload()

        // Renames arrive through @Model observation; only inserts and deletes change the list.
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

    func area(withId areaId: String) -> AreaEntity? {
        areasById[areaId]
    }

    private func reload() {
        let descriptor = FetchDescriptor<AreaEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        areas = (try? context.fetch(descriptor)) ?? []
        areasById = Dictionary(areas.map { ($0.areaId, $0) }) { first, _ in first }
        hasFloors = ((try? context.fetchCount(FetchDescriptor<FloorEntity>())) ?? 0) > 0
    }
}
