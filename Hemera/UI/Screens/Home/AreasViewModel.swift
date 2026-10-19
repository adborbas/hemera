import Foundation
import SwiftData

@Observable
@MainActor
final class AreasViewModel {

    private(set) var isRetrying = false

    let isDemoMode: Bool
    let haWebViewPresenter: HAWebViewPresenter
    let viewModelFactory: ViewModelFactory
    let homeTileRepository: any HomeTileRepository

    var syncFailed: Bool {
        errorNotifier?.syncFailed ?? false
    }

    /// Owned here so the toolbar's "View Options" toggle can bind to it.
    var areasGroupedByFloor: Bool {
        didSet { store.areasGroupedByFloor = areasGroupedByFloor }
    }

    private let store: any SettingsStoring
    private let errorNotifier: ErrorNotifier?
    private let connectionRetrier: (any ConnectionRetrying)?
    private var retryTimeoutTask: Task<Void, Never>?
    private let resync: () async -> Void

    init(
        homeTileRepository: any HomeTileRepository,
        viewModelFactory: ViewModelFactory,
        demoCoordinator: any DemoCoordinating,
        authManager: any AuthManaging,
        store: any SettingsStoring,
        errorNotifier: ErrorNotifier? = nil,
        connectionRetrier: (any ConnectionRetrying)? = nil,
        resync: @escaping () async -> Void = { }
    ) {
        self.homeTileRepository = homeTileRepository
        self.viewModelFactory = viewModelFactory
        self.isDemoMode = demoCoordinator.isActive
        self.haWebViewPresenter = HAWebViewPresenter(authManager: authManager)
        self.store = store
        self.areasGroupedByFloor = store.areasGroupedByFloor
        self.errorNotifier = errorNotifier
        self.connectionRetrier = connectionRetrier
        self.resync = resync
    }

    func refresh() async {
        await resync()
    }

    func retrySyncAndReload() {
        isRetrying = true
        connectionRetrier?.retryConnection()
        retryTimeoutTask?.cancel()
        retryTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            isRetrying = false
        }
    }

    func makeDetailViewModel(destination: AreaDestination) -> AreaDetailViewModel {
        AreaDetailViewModel(
            destination: destination,
            isDemoMode: isDemoMode,
            homeTileRepository: homeTileRepository,
            haWebViewPresenter: haWebViewPresenter,
            viewModelFactory: viewModelFactory
        )
    }

    // MARK: - Grid Filtering

    /**
     Areas with at least one HA-visible entity (or climate data) to display.
     Empty areas — and areas whose entities are all hidden in Home Assistant — are
     dropped. An area whose entities are only locally hidden still shows (with no
     status icons) so it stays reachable to reveal them.
    */
    func displayedAreas(from areas: [AreaEntity]) -> [AreaEntity] {
        areas.filter { area in
            area.lights.contains { !$0.isHiddenInHA }
                || area.covers.contains { !$0.isHiddenInHA }
                || area.scenes.contains { !$0.isHiddenInHA }
                || area.scripts.contains { !$0.isHiddenInHA }
                || area.switches.contains { !$0.isHiddenInHA }
                || area.buttons.contains { !$0.isHiddenInHA }
                || area.automations.contains { !$0.isHiddenInHA }
                || area.binarySensors.contains { !$0.isHiddenInHA }
                || area.climates.contains { !$0.isHiddenInHA }
                || hasClimateData(in: area)
        }
    }

    func isGridEmpty(displayedAreaCount: Int, hasUnassigned: Bool) -> Bool {
        displayedAreaCount == 0 && !hasUnassigned
    }

    private func hasClimateData(in area: AreaEntity) -> Bool {
        let (temp, humidity) = AreaDisplayHelpers.climateSummary(from: area.sensors)
        return temp != nil || humidity != nil
    }

    // MARK: - Sectioning

    /// A group of area cards rendered under an optional header.
    struct AreaSection: Identifiable {
        let id: String
        /// The floor name, or `nil` for the flat (headerless) layout.
        let title: String?
        let areas: [AreaEntity]
        /// Whether the synthetic "Unassigned" card belongs to this section.
        let includesUnassigned: Bool
    }

    /// Groups displayed areas into sections for the grid.
    ///
    /// - When grouping is off, or Home Assistant has no floors, returns a single
    ///   headerless section (the flat grid, rendered exactly as before).
    /// - Otherwise returns one section per floor (in floor `sortOrder`),
    ///   dropping floors with no displayed areas, followed by a trailing
    ///   localized "Other" section for floorless areas and/or the Unassigned
    ///   card. The "Other" section is present whenever floorless areas exist or
    ///   there are unassigned entities.
    func sections(
        from areas: [AreaEntity],
        floors: [FloorEntity],
        groupingEnabled: Bool,
        hasUnassigned: Bool
    ) -> [AreaSection] {
        let displayed = displayedAreas(from: areas)

        guard groupingEnabled, !floors.isEmpty else {
            return [AreaSection(id: Self.flatSectionId, title: nil, areas: displayed, includesUnassigned: hasUnassigned)]
        }

        let floorIds = Set(floors.map(\.floorId))
        var result: [AreaSection] = []

        for floor in floors.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let floorAreas = displayed.filter { $0.floor?.floorId == floor.floorId }
            guard !floorAreas.isEmpty else { continue }
            result.append(AreaSection(id: floor.floorId, title: floor.name, areas: floorAreas, includesUnassigned: false))
        }

        // Areas with no floor — or referencing a floor that no longer exists —
        // fall into the trailing "Other" section, alongside the Unassigned card.
        let otherAreas = displayed.filter { area in
            guard let floorId = area.floor?.floorId else { return true }
            return !floorIds.contains(floorId)
        }
        if !otherAreas.isEmpty || hasUnassigned {
            result.append(AreaSection(id: Self.otherSectionId, title: Localization.other, areas: otherAreas, includesUnassigned: hasUnassigned))
        }

        return result
    }

    private static let flatSectionId = "__all__"
    private static let otherSectionId = "__other__"

}

// MARK: - Localization

private extension AreasViewModel {
    enum Localization {
        static let other = String(
            localized: "Other",
            comment: "Section header on the Areas screen grouping areas that are not assigned to any floor, plus entities not assigned to any area"
        )
    }
}
