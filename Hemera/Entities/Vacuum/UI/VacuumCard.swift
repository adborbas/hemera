import SwiftUI
import Mortar

struct VacuumCard: View {
    var viewModel: VacuumCardViewModel

    var body: some View {
        EntityCard(tintColor: viewModel.tintColor,
                   isActive: viewModel.isActive,
                   isWorking: viewModel.isWorking) {
            CardIcon(icon: viewModel.iconName,
                     backgroundColor: viewModel.iconBackgroundColor,
                     actionLabel: viewModel.iconActionLabel) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.iconTapped()
            }
            .accessibilityIdentifier("\(viewModel.id).icon")
        } label: {
            CardLabel(title: viewModel.name,
                      subtitle: viewModel.stateDescription,
                      accessibilityIdentifier: viewModel.id)
        }
        .unavailableStyle(viewModel.isAvailable)
        .animation(Mortar.Motion.springNormal, value: viewModel.state)
    }
}

#if DEBUG
#Preview("State") {
    ScrollView {
        ForEach(VacuumEntity.State.allCases) { state in
            VacuumCard(viewModel: VacuumCardViewModel.mock(state: state))
        }
    }
    .padding(12)
}

fileprivate extension VacuumCardViewModel {
    static func mock(state: VacuumEntity.State) -> VacuumCardViewModel {
        let features: VacuumEntity.Features = [.start, .pause, .stop, .returnHome, .locate]
        let vacuum = VacuumEntity(entityId: "vacuum.robot", name: "Robot Vacuum", state: state, supportedFeaturesRaw: features.rawValue)
        return VacuumCardViewModel(vacuum: vacuum, controller: MockVacuumControlling())
    }
}

private struct MockVacuumControlling: VacuumControlling {
    func startVacuum(_ id: String) async {}
    func pauseVacuum(_ id: String) async {}
    func stopVacuum(_ id: String) async {}
    func returnVacuumToBase(_ id: String) async {}
    func locateVacuum(_ id: String) async {}
}
#endif
