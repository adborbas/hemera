import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class ScriptCardViewModel: Identifiable {
    private(set) var script: ScriptEntity

    nonisolated let id: String
    var name: String { script.name }
    var isAvailable: Bool { script.isAvailable }
    var isRunning: Bool { script.isRunning }
    var deviceId: String? { script.deviceId }
    var isHidden: Bool {
        get { script.isHidden }
        set { script.isHidden = newValue }
    }

    var iconName: String {
        if let icon = script.icon,
           let sfSymbol = MDISymbolMapper.entitySFSymbol(for: icon) {
            return sfSymbol
        }
        return "play.circle.fill"
    }

    var tintColor: Color { .purple }

    private let controller: ScriptControlling

    init(script: ScriptEntity, controller: ScriptControlling) {
        self.id = script.entityId
        self.script = script
        self.controller = controller
    }

    func run() {
        guard script.isAvailable else { return }
        Task {
            await controller.runScript(id)
        }
    }

    func cancel() {
        guard script.isAvailable else { return }
        Task {
            await controller.cancelScript(id)
        }
    }
}

// MARK: - Factory Registration

extension ScriptCardViewModel {
    static func registration(controller: ScriptControlling) -> ViewModelFactory.Registration {
        ViewModelFactory.Registration(
            domain: ScriptEntity.domain,
            makeViewModelsForArea: { area in
                area.scripts.filter { !$0.isHiddenInHA }.sorted(by: { $0.entityId < $1.entityId }).map {
                    ScriptCardViewModel(script: $0, controller: controller)
                }
            },
            makeViewModelForEntityId: { entityId, context in
                guard let script = ScriptEntity.fetch(byId: entityId, in: context) else { return nil }
                return ScriptCardViewModel(script: script, controller: controller)
            },
            entityExists: { entityId, context in
                ScriptEntity.fetch(byId: entityId, in: context) != nil
            }
        )
    }
}

// MARK: - EntityCardViewModel

extension ScriptCardViewModel: EntityCardViewModel {
    func makeCardView() -> AnyView {
        AnyView(ScriptCard(viewModel: self))
    }

    func performPrimaryAction() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if isRunning {
            cancel()
        } else {
            run()
        }
    }
}
