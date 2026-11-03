import Foundation
import SwiftData
import TileGridEngine

/// Every entity of one domain, one section per area in Home Assistant order, then "Other".
@Observable
@MainActor
final class EntityFeedViewModel {

    let isDemoMode: Bool
    let haWebViewPresenter: HAWebViewPresenter
    let viewModelFactory: ViewModelFactory

    private(set) var entities: [any StoredEntity] = []

    private let pillSummary: FeedSummary
    private let makeSubtitle: ([any StoredEntity]) -> String?
    private let tileSize: TileSize
    private let homeTileRepository: any HomeTileRepository
    private let fetchEntities: () -> [any StoredEntity]
    @ObservationIgnored private nonisolated(unsafe) var saveObserver: (any NSObjectProtocol)?

    init<Entity: StoredEntity>(
        _ entityType: Entity.Type,
        summary: FeedSummary,
        subtitle: @escaping ([Entity]) -> String? = { _ in nil },
        tileSize: TileSize,
        context: ModelContext,
        viewModelFactory: ViewModelFactory,
        homeTileRepository: any HomeTileRepository,
        haWebViewPresenter: HAWebViewPresenter,
        isDemoMode: Bool
    ) {
        self.pillSummary = summary
        self.makeSubtitle = { subtitle($0.compactMap { $0 as? Entity }) }
        self.tileSize = tileSize
        self.viewModelFactory = viewModelFactory
        self.homeTileRepository = homeTileRepository
        self.haWebViewPresenter = haWebViewPresenter
        self.isDemoMode = isDemoMode
        self.fetchEntities = { (try? context.fetch(FetchDescriptor<Entity>())) ?? [] }
        entities = fetchEntities()

        // Edits reach the grid through @Model observation; only inserts and deletes change who is in it.
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

    /// `nil` while nothing is visible, which hides the feed's pill.
    var summary: FeedSummary? {
        entities.contains { !$0.isHiddenInHA } ? pillSummary : nil
    }

    var subtitle: String? {
        makeSubtitle(visibleEntities)
    }

    var sections: [TileSection] {
        let groups = Dictionary(grouping: visibleEntities) { $0.area?.areaId }
        let orderedGroups = groups.values.sorted { lhs, rhs in
            switch (lhs[0].area, rhs[0].area) {
            case let (left?, right?): (left.sortOrder, left.name) < (right.sortOrder, right.name)
            case (.some, nil): true
            default: false
            }
        }
        return orderedGroups.map { group in
            let byName = group.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return TileSection(
                title: group[0].area?.name ?? Localization.other,
                tiles: byName.map { Tile(id: UUID(stableForString: $0.entityId), title: $0.name, size: tileSize) }
            )
        }
    }

    var entityIdByTileId: [Tile.ID: String] {
        Dictionary(entities.map { (UUID(stableForString: $0.entityId), $0.entityId) }) { first, _ in first }
    }

    func isOnHome(entityId: String) -> Bool {
        homeTileRepository.isOnHome(entityId: entityId)
    }

    func addToHome(entityId: String) {
        homeTileRepository.addToHome(entityId: entityId)
    }

    func openEntityInHA(entityId: String, deviceId: String?) {
        haWebViewPresenter.openEntity(entityId, deviceId: deviceId)
    }

    private var visibleEntities: [any StoredEntity] {
        entities.filter { !$0.isHiddenInHA }
    }

    private func reload() {
        entities = fetchEntities()
    }
}

private extension EntityFeedViewModel {
    enum Localization {
        static let other = String(
            localized: "Other",
            comment: "Section header in a feed such as Lights grouping entities that are not assigned to any area"
        )
    }
}
