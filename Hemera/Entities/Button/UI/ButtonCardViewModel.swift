import Foundation
import Mortar
import SwiftData
import SwiftUI

@Observable
@MainActor
final class ButtonCardViewModel: Identifiable {
    private(set) var button: ButtonEntity

    nonisolated let id: String
    var name: String { button.name }
    var isAvailable: Bool { button.isAvailable }
    var deviceId: String? { button.deviceId }
    var requiresConfirmation: Bool { button.deviceClass.requiresConfirmation }

    var iconName: String {
        if let icon = button.icon,
           let sfSymbol = MDISymbolMapper.entitySFSymbol(for: icon) {
            return sfSymbol
        }
        switch button.deviceClass {
        case .restart: return "arrow.clockwise.circle.fill"
        case .update: return "arrow.down.circle.fill"
        case .identify: return "eye.circle.fill"
        case .unknown: return "button.horizontal.top.press"
        }
    }

    var iconBackgroundColor: Color {
        switch button.deviceClass {
        case .restart: .orange
        case .update: .green
        case .identify: .purple
        case .unknown: PlatformColor.systemGray3
        }
    }

    var subtitle: String {
        switch button.deviceClass {
        case .restart: Localization.restart
        case .update: Localization.update
        case .identify: Localization.identify
        case .unknown: Localization.press
        }
    }

    private let controller: ButtonControlling
    private(set) var controllerTask: Task<Void, Never>?

    init(button: ButtonEntity, controller: ButtonControlling) {
        self.id = button.entityId
        self.button = button
        self.controller = controller
    }

    func press() {
        guard button.isAvailable else { return }
        controllerTask = Task {
            await controller.pressButton(id)
        }
    }
}

// MARK: - Factory Registration

extension ButtonCardViewModel {
    static func registration(controller: ButtonControlling) -> ViewModelFactory.Registration {
        ViewModelFactory.Registration(
            makeViewModelsForArea: { area in
                area.buttons.filter { $0.deviceClass.isUserActionable }.sorted(by: { $0.entityId < $1.entityId }).map {
                    ButtonCardViewModel(button: $0, controller: controller)
                }
            },
            makeViewModelForEntityId: { entityId, context in
                guard let button = ButtonEntity.fetch(byId: entityId, in: context),
                      button.deviceClass.isUserActionable else { return nil }
                return ButtonCardViewModel(button: button, controller: controller)
            }
        )
    }
}

// MARK: - EntityCardViewModel

extension ButtonCardViewModel: EntityCardViewModel {
    func makeCardView() -> AnyView {
        AnyView(ButtonCard(viewModel: self))
    }
}

// MARK: - Localization

private extension ButtonCardViewModel {
    enum Localization {
        static let restart = String(localized: "Restart", comment: "Subtitle for a restart button card")
        static let update = String(localized: "Update", comment: "Subtitle for an update button card")
        static let identify = String(localized: "Identify", comment: "Subtitle for an identify button card")
        static let press = String(localized: "Press", comment: "Subtitle for a generic button card")
    }
}
