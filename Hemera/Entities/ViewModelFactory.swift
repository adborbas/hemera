import Foundation
import SwiftData
import SwiftUI

/// Creates `EntityCardViewModel` instances using registered domain factories.
///
/// Entity domains register their VM creation logic via `register(_:)`.
/// This eliminates the need to modify this class when adding new entity types —
/// each domain owns its own registration.
///
/// Caches VMs by entityId for the factory's lifetime (session-scoped). The
/// same `entityId` always returns the same VM instance — preserving ephemeral
/// interaction state (pending values, cooldowns) across view re-renders.
@MainActor
final class ViewModelFactory {

    /// A pair of closures that create ViewModels for a single entity domain.
    struct Registration {
        /// Creates all ViewModels for entities of this domain within an area.
        let makeViewModelsForArea: @MainActor (AreaEntity) -> [any EntityCardViewModel]
        /// Creates a ViewModel for a single entity by ID, if it exists in storage.
        let makeViewModelForEntityId: @MainActor (String, ModelContext) -> (any EntityCardViewModel)?
    }

    private var registrations: [Registration] = []
    private var cache: [String: any EntityCardViewModel] = [:]
    private let context: ModelContext
    /// Retains the container so its entities stay valid as long as this factory (and any VMs it created) are alive.
    /// In production the container is app-scoped and never released; in demo mode this prevents premature deallocation
    /// when `SessionManager.tearDownDemoSession()` drops its own reference.
    private let container: ModelContainer

    init(context: ModelContext, container: ModelContainer) {
        self.context = context
        self.container = container
    }

    /// Registers a domain's ViewModel factory.
    func register(_ registration: Registration) {
        registrations.append(registration)
    }

    /// Registers all built-in entity domain factories.
    ///
    /// Consolidates domain registration so adding a new entity type requires a single-line addition here.
    func registerAllDomains(
        lightController: some LightControlling,
        coverController: some CoverControlling,
        sceneController: some SceneControlling,
        switchController: some SwitchControlling,
        buttonController: some ButtonControlling,
        automationController: some AutomationControlling,
        climateController: some ClimateControlling
    ) {
        register(LightCardViewModel.registration(controller: lightController))
        register(CoverCardViewModel.registration(controller: coverController))
        register(SceneCardViewModel.registration(controller: sceneController))
        register(BinarySensorCardViewModel.registration())
        register(SwitchCardViewModel.registration(controller: switchController))
        register(ButtonCardViewModel.registration(controller: buttonController))
        register(AutomationCardViewModel.registration(controller: automationController))
        register(ClimateCardViewModel.registration(controller: climateController))
    }

    // MARK: - Area-Level VM Creation

    /// Creates all entity card view models for an area, looking up each by entityId
    /// through the cache so the same VM instance is reused across rebuilds.
    func makeViewModels(for area: AreaEntity) -> [any EntityCardViewModel] {
        registrations.flatMap { registration in
            registration.makeViewModelsForArea(area).map { fresh in
                cachedOrAdopt(fresh)
            }
        }
    }

    // MARK: - Entity-Level VM Creation

    /// Returns the cached VM for the entity, or creates one by looking it up in storage.
    func makeViewModel(forEntityId entityId: String) -> (any EntityCardViewModel)? {
        if let cached = cache[entityId] { return cached }
        for registration in registrations {
            if let vm = registration.makeViewModelForEntityId(entityId, context) {
                cache[entityId] = vm
                return vm
            }
        }
        return nil
    }

    /// If a VM for this entityId is already cached, return the cached instance;
    /// otherwise adopt the freshly-built one.
    private func cachedOrAdopt(_ fresh: any EntityCardViewModel) -> any EntityCardViewModel {
        if let cached = cache[fresh.id] { return cached }
        cache[fresh.id] = fresh
        return fresh
    }

    // MARK: - Card Tap

    /// Dispatches a card tap. Returns the card VM if the entity has an
    /// overlay (the view should present it); returns `nil` when the entity
    /// is unavailable or its primary action was invoked in place.
    func handleCardTap(entityId: String) -> (any EntityCardViewModel)? {
        guard let vm = makeViewModel(forEntityId: entityId), vm.isAvailable else { return nil }
        if vm.makeOverlayView(isPresented: .constant(true)) != nil {
            return vm
        }
        vm.performPrimaryAction()
        return nil
    }
}
