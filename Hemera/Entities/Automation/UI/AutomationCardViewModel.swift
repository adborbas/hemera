import Foundation
import Mortar
import SwiftData
import SwiftUI

@Observable
@MainActor
final class AutomationCardViewModel: Identifiable {
    private(set) var automation: AutomationEntity

    nonisolated let id: String
    var name: String { automation.name }
    var isOn: Bool { automation.isOn }
    var isAvailable: Bool { automation.isAvailable }
    var deviceId: String? { automation.deviceId }
    var lastTriggered: Date? { automation.lastTriggered }

    var iconName: String {
        if let icon = automation.icon,
           let sfSymbol = MDISymbolMapper.entitySFSymbol(for: icon) {
            return sfSymbol
        }
        return "gearshape.2.fill"
    }

    var iconBackgroundColor: Color {
        isOn ? .orange : PlatformColor.systemGray3
    }

    var tintColor: Color { .orange }

    private let controller: AutomationControlling

    init(automation: AutomationEntity, controller: AutomationControlling) {
        self.id = automation.entityId
        self.automation = automation
        self.controller = controller
    }

    func toggle() {
        guard automation.isAvailable else { return }
        Task {
            await controller.setAutomation(id, on: !isOn)
        }
    }

    func trigger() {
        guard automation.isAvailable else { return }
        Task {
            await controller.triggerAutomation(id)
        }
    }
}

// MARK: - Factory Registration

extension AutomationCardViewModel {
    static func registration(controller: AutomationControlling) -> ViewModelFactory.Registration {
        ViewModelFactory.Registration(
            makeViewModelsForArea: { area in
                area.automations.sorted(by: { $0.entityId < $1.entityId }).map {
                    AutomationCardViewModel(automation: $0, controller: controller)
                }
            },
            makeViewModelForEntityId: { entityId, context in
                guard let automation = AutomationEntity.fetch(byId: entityId, in: context) else { return nil }
                return AutomationCardViewModel(automation: automation, controller: controller)
            }
        )
    }
}

// MARK: - EntityCardViewModel

extension AutomationCardViewModel: EntityCardViewModel {
    func makeCardView() -> AnyView {
        AnyView(AutomationCard(viewModel: self))
    }

    var hasOverlay: Bool { true }

    func makeOverlayView(isPresented: Binding<Bool>) -> AnyView? {
        AnyView(AutomationControlPanel(viewModel: self, isPresented: isPresented))
    }
}
