import Foundation
import Mortar
import SwiftData
import SwiftUI

@Observable
@MainActor
final class SwitchCardViewModel: Identifiable {
    private(set) var switchEntity: SwitchEntity

    nonisolated let id: String
    var name: String { switchEntity.name }
    var isOn: Bool { switchEntity.isOn }
    var isAvailable: Bool { switchEntity.isAvailable }
    var deviceId: String? { switchEntity.deviceId }
    var deviceClass: SwitchEntity.DeviceClass { switchEntity.deviceClass }

    var iconName: String {
        if let icon = switchEntity.icon,
           let sfSymbol = MDISymbolMapper.entitySFSymbol(for: icon) {
            return sfSymbol
        }
        switch deviceClass {
        case .outlet: return "powerplug.fill"
        case .switch: return "power"
        }
    }

    var iconBackgroundColor: Color {
        isOn ? .green : PlatformColor.systemGray3
    }

    var tintColor: Color { .green }

    private let controller: SwitchControlling
    private(set) var controllerTask: Task<Void, Never>?

    init(switchEntity: SwitchEntity, controller: SwitchControlling) {
        self.id = switchEntity.entityId
        self.switchEntity = switchEntity
        self.controller = controller
    }

    func toggle() {
        guard switchEntity.isAvailable else { return }
        controllerTask = Task {
            await controller.setSwitch(id, on: !isOn)
        }
    }

    func setOn(_ on: Bool) {
        controllerTask = Task {
            await controller.setSwitch(id, on: on)
        }
    }
}

// MARK: - Factory Registration

extension SwitchCardViewModel {
    static func registration(controller: SwitchControlling) -> ViewModelFactory.Registration {
        ViewModelFactory.Registration(
            makeViewModelsForArea: { area in
                area.switches.sorted(by: { $0.entityId < $1.entityId }).map {
                    SwitchCardViewModel(switchEntity: $0, controller: controller)
                }
            },
            makeViewModelForEntityId: { entityId, context in
                guard let switchEntity = SwitchEntity.fetch(byId: entityId, in: context) else { return nil }
                return SwitchCardViewModel(switchEntity: switchEntity, controller: controller)
            }
        )
    }
}

// MARK: - EntityCardViewModel

extension SwitchCardViewModel: EntityCardViewModel {
    func makeCardView() -> AnyView {
        AnyView(SwitchCard(viewModel: self))
    }

    func makeOverlayView(isPresented: Binding<Bool>) -> AnyView? {
        AnyView(SwitchControlPanel(viewModel: self, isPresented: isPresented))
    }
}
