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

    private let errorNotifier: ErrorNotifier?
    private let connectionRetrier: (any ConnectionRetrying)?
    private var retryTimeoutTask: Task<Void, Never>?
    private let resync: () async -> Void

    init(
        homeTileRepository: any HomeTileRepository,
        viewModelFactory: ViewModelFactory,
        demoCoordinator: any DemoCoordinating,
        authManager: any AuthManaging,
        errorNotifier: ErrorNotifier? = nil,
        connectionRetrier: (any ConnectionRetrying)? = nil,
        resync: @escaping () async -> Void = { }
    ) {
        self.homeTileRepository = homeTileRepository
        self.viewModelFactory = viewModelFactory
        self.isDemoMode = demoCoordinator.isActive
        self.haWebViewPresenter = HAWebViewPresenter(authManager: authManager)
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

    /// Areas that have at least one entity (or climate data) to display.
    /// Empty areas are hidden from the grid.
    func displayedAreas(from areas: [AreaEntity]) -> [AreaEntity] {
        areas.filter { area in
            !area.lights.isEmpty
                || !area.covers.isEmpty
                || !area.scenes.isEmpty
                || !area.switches.isEmpty
                || !area.buttons.isEmpty
                || !area.automations.isEmpty
                || !area.binarySensors.isEmpty
                || !area.climates.isEmpty
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

}
