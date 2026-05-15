import SwiftUI
import Mortar

struct AutomationCard: View {
    var viewModel: AutomationCardViewModel

    var body: some View {
        EntityCard(tintColor: viewModel.tintColor, isActive: viewModel.isOn) {
            CardIcon(iconName: viewModel.iconName,
                     backgroundColor: viewModel.iconBackgroundColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.toggle()
            }
        } label: {
            CardLabel(title: viewModel.name,
                      subtitle: viewModel.isOn ? Localization.on : Localization.off)
        }
        .unavailableStyle(viewModel.isAvailable)
        .animation(Mortar.Motion.springNormal, value: viewModel.isOn)
    }
}

private extension AutomationCard {
    enum Localization {
        static let on = String(localized: "On", comment: "Automation entity state shown on card when the automation is enabled")
        static let off = String(localized: "Off", comment: "Automation entity state shown on card when the automation is disabled")
    }
}

#if DEBUG
#Preview {
    VStack {
        AutomationCard(viewModel: AutomationCardViewModel.mockAutomation(isOn: true))
        AutomationCard(viewModel: AutomationCardViewModel.mockAutomation(isOn: false))
    }
    .padding(12)
}

fileprivate extension AutomationCardViewModel {
    static func mockAutomation(isOn: Bool) -> AutomationCardViewModel {
        let entity = AutomationEntity(
            entityId: "automation.motion_lights",
            name: "Motion Lights",
            state: isOn ? .on : .off,
            lastTriggered: Date().addingTimeInterval(-300)
        )
        return AutomationCardViewModel(automation: entity, controller: MockAutomationControlling())
    }
}

private class MockAutomationControlling: AutomationControlling {
    func setAutomation(_ id: String, on: Bool) async {}
    func triggerAutomation(_ id: String) async {}
}
#endif
