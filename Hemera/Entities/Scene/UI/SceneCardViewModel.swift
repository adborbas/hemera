import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class SceneCardViewModel: Identifiable {
    private(set) var scene: SceneEntity

    nonisolated let id: String
    var name: String { scene.name }
    var isAvailable: Bool { scene.isAvailable }
    var deviceId: String? { scene.deviceId }
    var isHidden: Bool {
        get { scene.isHidden }
        set { scene.isHidden = newValue }
    }

    var iconName: String? {
        iconResolver.iconName(domain: SceneEntity.domain, entityIcon: scene.icon)
    }

    private let controller: SceneControlling
    private let iconResolver: any IconResolving

    init(scene: SceneEntity, controller: SceneControlling, iconResolver: any IconResolving = IconResolver.shared) {
        self.id = scene.entityId
        self.scene = scene
        self.controller = controller
        self.iconResolver = iconResolver
    }

    func activate() {
        guard scene.isAvailable else { return }
        Task {
            await controller.activateScene(id)
        }
    }
}

// MARK: - Factory Registration

extension SceneCardViewModel {
    static func registration(controller: SceneControlling) -> ViewModelFactory.Registration {
        ViewModelFactory.Registration(
            domain: SceneEntity.domain,
            makeViewModelsForArea: { area in
                area.scenes.filter { !$0.isHiddenInHA }.sorted(by: { $0.entityId < $1.entityId }).map {
                    SceneCardViewModel(scene: $0, controller: controller)
                }
            },
            makeViewModelForEntityId: { entityId, context in
                guard let scene = SceneEntity.fetch(byId: entityId, in: context) else { return nil }
                return SceneCardViewModel(scene: scene, controller: controller)
            },
            entityExists: { entityId, context in
                SceneEntity.fetch(byId: entityId, in: context) != nil
            }
        )
    }
}

// MARK: - EntityCardViewModel

extension SceneCardViewModel: EntityCardViewModel {
    func makeCardView() -> AnyView {
        AnyView(SceneCard(viewModel: self))
    }

    func performPrimaryAction() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        activate()
    }
}
