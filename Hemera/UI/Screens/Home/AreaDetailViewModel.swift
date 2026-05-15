import Foundation
import TileGridEngine

@Observable
@MainActor
final class AreaDetailViewModel {

    let destination: AreaDestination
    let isDemoMode: Bool
    let haWebViewPresenter: HAWebViewPresenter
    let viewModelFactory: ViewModelFactory

    var isVirtualArea: Bool { destination.isVirtual }
    var areaName: String { destination.displayName }

    private let homeTileRepository: any HomeTileRepository

    init(
        destination: AreaDestination,
        isDemoMode: Bool,
        homeTileRepository: any HomeTileRepository,
        haWebViewPresenter: HAWebViewPresenter,
        viewModelFactory: ViewModelFactory
    ) {
        self.destination = destination
        self.isDemoMode = isDemoMode
        self.homeTileRepository = homeTileRepository
        self.haWebViewPresenter = haWebViewPresenter
        self.viewModelFactory = viewModelFactory
    }

    func isOnHome(entityId: String) -> Bool {
        homeTileRepository.isOnHome(entityId: entityId)
    }

    func addToHome(entityId: String) {
        homeTileRepository.addToHome(entityId: entityId)
    }

    func openAreaInHA() {
        guard case .area(let area) = destination else { return }
        haWebViewPresenter.openArea(area.areaId)
    }

    func openEntityInHA(entityId: String, deviceId: String?) {
        haWebViewPresenter.openEntity(entityId, deviceId: deviceId)
    }

    // MARK: - Categorization

    /// Builds categorized sections for a real area by enumerating the area's
    /// relationships through the factory's session-scoped cache.
    func sections(for area: AreaEntity) -> [CategorizedSection] {
        let cardVMs = viewModelFactory.makeViewModels(for: area)
        return CategorizedSection.build(from: cardVMs)
    }

    /// Builds categorized sections for the virtual unassigned area. The view
    /// supplies the entity IDs from its per-domain `@Query` results.
    func sections(forUnassignedEntityIds entityIds: [String]) -> [CategorizedSection] {
        let cardVMs = entityIds.compactMap { viewModelFactory.makeViewModel(forEntityId: $0) }
        return CategorizedSection.build(from: cardVMs)
    }

    // MARK: - Layout

    /// Column count for the area-detail grid. Compact size class always uses
    /// 4; regular adapts to orientation.
    func columnCount(isCompactWidth: Bool, isLandscape: Bool) -> Int {
        if isCompactWidth {
            return 4
        } else {
            return isLandscape ? 12 : 8
        }
    }

}

// MARK: - CategorizedSection

/// A pure-value section that lives only for the duration of a body
/// evaluation. The `vmsByTileId` map carries the card VM references so the
/// section renders without any extra lookups.
struct CategorizedSection {
    let id: String
    let title: String?
    let tiles: [Tile]
    let vmsByTileId: [Tile.ID: any EntityCardViewModel]

    static func build(from cardVMs: [any EntityCardViewModel]) -> [CategorizedSection] {
        var byCategory: [EntityCategory: [any EntityCardViewModel]] = [:]
        var uncategorized: [any EntityCardViewModel] = []

        for vm in cardVMs {
            if let category = EntityCategory.from(entityId: vm.id) {
                byCategory[category, default: []].append(vm)
            } else {
                uncategorized.append(vm)
            }
        }

        var sections: [CategorizedSection] = EntityCategory.allCases.compactMap { category in
            guard let vms = byCategory[category], !vms.isEmpty else { return nil }
            return CategorizedSection(category: category.title, vms: vms, id: "category.\(category.rawValue)")
        }

        if !uncategorized.isEmpty {
            sections.append(CategorizedSection(category: Localization.other, vms: uncategorized, id: "category.other"))
        }

        // If there's only one section, drop its title so the grid looks clean.
        if sections.count == 1 {
            sections[0] = CategorizedSection(category: nil, vms: sections[0].vms, id: sections[0].id)
        }
        return sections
    }

    private init(category title: String?, vms: [any EntityCardViewModel], id: String) {
        self.id = id
        self.title = title
        self.vmsByTileId = Dictionary(uniqueKeysWithValues: vms.map { vm in
            (UUID(stableForString: vm.id), vm)
        })
        self.tiles = vms.map { vm in
            Tile(id: UUID(stableForString: vm.id), title: vm.name, size: .small)
        }
    }

    /// Internal accessor used by `build` to reconstruct a section with a
    /// dropped title when only one section exists.
    fileprivate var vms: [any EntityCardViewModel] {
        tiles.compactMap { vmsByTileId[$0.id] }
    }
}

private extension CategorizedSection {
    enum Localization {
        static let other = String(
            localized: "Other",
            comment: "Section header for entities whose domain has no assigned category in area detail view"
        )
    }
}
