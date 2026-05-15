import SwiftUI
import Mortar

struct BinarySensorCard: View {
    var viewModel: BinarySensorCardViewModel

    var body: some View {
        EntityCard(tintColor: viewModel.tintColor, isActive: viewModel.isOn) {
            CardIcon(
                iconName: viewModel.iconName,
                backgroundColor: viewModel.iconBackgroundColor
            )
        } label: {
            CardLabel(title: viewModel.name, subtitle: viewModel.stateDescription)
        }
        .unavailableStyle(viewModel.isAvailable)
        .animation(Mortar.Motion.springNormal, value: viewModel.isOn)
    }
}

#if DEBUG
#Preview("Device classes") {
    @Previewable @State var isOn = true

    VStack {
        Toggle(isOn: $isOn) {
            Text("Is on")
        }
        ScrollView {
            ForEach(BinarySensorEntity.DeviceClass.allCases) { deviceClass in
                BinarySensorCard(viewModel: .mock(
                    state: isOn ? .on : .off,
                    deviceClass: deviceClass
                ))
            }
        }
    }
    .padding(12)
}

#Preview("States") {
    VStack {
        ForEach(BinarySensorEntity.State.allCases) { state in
            BinarySensorCard(viewModel: .mock(state: state, deviceClass: .motion))
        }
    }
    .padding(12)
}

fileprivate extension BinarySensorCardViewModel {
    static func mock(
        state: BinarySensorEntity.State,
        deviceClass: BinarySensorEntity.DeviceClass = .unknown
    ) -> BinarySensorCardViewModel {
        let entity = BinarySensorEntity(
            entityId: "binary_sensor.\(deviceClass.rawValue)",
            name: deviceClass.rawValue.capitalized,
            state: state,
            deviceClass: deviceClass
        )
        return BinarySensorCardViewModel(binarySensor: entity)
    }
}
#endif
