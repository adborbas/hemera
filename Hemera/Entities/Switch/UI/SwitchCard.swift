import SwiftUI
import Mortar

struct SwitchCard: View {
    var viewModel: SwitchCardViewModel

    var body: some View {
        EntityCard(tintColor: viewModel.tintColor, isActive: viewModel.isOn) {
            CardIcon(iconName: viewModel.iconName,
                     backgroundColor: viewModel.iconBackgroundColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.toggle()
            }
        } label: {
            CardLabel(title: viewModel.name,
                      subtitle: viewModel.isOn ? Localization.on : Localization.off,
                      accessibilityIdentifier: viewModel.id)
        }
        .unavailableStyle(viewModel.isAvailable)
        .animation(Mortar.Motion.springNormal, value: viewModel.isOn)
    }
}

private extension SwitchCard {
    enum Localization {
        static let on = String(localized: "On", comment: "Switch entity state shown on card when the switch is turned on")
        static let off = String(localized: "Off", comment: "Switch entity state shown on card when the switch is turned off")
    }
}

#if DEBUG
#Preview {
    VStack {
        SwitchCard(viewModel: SwitchCardViewModel.mockSwitch(isOn: true))
        SwitchCard(viewModel: SwitchCardViewModel.mockSwitch(isOn: false))
        SwitchCard(viewModel: SwitchCardViewModel.mockOutlet(isOn: true))
    }
    .padding(12)
}

fileprivate extension SwitchCardViewModel {
    static func mockSwitch(isOn: Bool) -> SwitchCardViewModel {
        let entity = SwitchEntity(entityId: "switch.fan", name: "Fan", state: isOn ? .on : .off, deviceClass: .switch)
        return SwitchCardViewModel(switchEntity: entity, controller: MockSwitchControlling())
    }

    static func mockOutlet(isOn: Bool) -> SwitchCardViewModel {
        let entity = SwitchEntity(entityId: "switch.coffee", name: "Coffee Machine", state: isOn ? .on : .off, deviceClass: .outlet)
        return SwitchCardViewModel(switchEntity: entity, controller: MockSwitchControlling())
    }
}

private class MockSwitchControlling: SwitchControlling {
    func setSwitch(_ id: String, on: Bool) async {}
}
#endif
