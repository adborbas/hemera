import SwiftUI
import Mortar

struct CoverCard: View {
    var viewModel: CoverCardViewModel
    @Environment(\.isMediumTile) private var isMediumTile

    private var fillFraction: CGFloat {
        guard viewModel.isOpen, let position = viewModel.position else { return 0 }
        return CGFloat(100 - position) / 100.0
    }

    var body: some View {
        EntityCard(tintColor: viewModel.tintColor, isActive: viewModel.isOpen) {
            CardIcon(iconName: viewModel.iconName,
                     backgroundColor: viewModel.iconBackgroundColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.iconTapped()
            }
        } label: {
            CardLabel(title: viewModel.name,
                      subtitle: isMediumTile ? viewModel.simpleStateDescription : viewModel.stateDescription,
                      accessibilityIdentifier: viewModel.id)
        } backgroundOverlay: {
            if isMediumTile {
                CardFillOverlay(fraction: fillFraction, fillColor: viewModel.tintColor, anchor: .top)
            }
        }
        .unavailableStyle(viewModel.isAvailable)
        .animation(Mortar.Motion.springNormal, value: viewModel.state)
        .animation(Mortar.Motion.springNormal, value: fillFraction)
    }
}

#if DEBUG
#Preview("State") {
    @Previewable @State var showsPosition: Bool = true

    VStack {
        Toggle(isOn: $showsPosition) {
            Text("Show position")
        }
        ScrollView {
            CoverCard(viewModel: CoverCardViewModel.mock(state: .open, position: showsPosition ? 100 : nil))
            ForEach(CoverEntity.State.allCases) { state in
                CoverCard(viewModel: CoverCardViewModel.mock(state: state, position: showsPosition ? 90 : nil))
            }
        }
    }
    .padding(12)
}

#Preview("Device class") {
    @Previewable @State var isOpen: Bool = true

    VStack {
        Toggle(isOn: $isOpen) {
            Text("Is open")
        }
        ScrollView {
            ForEach(CoverEntity.DeviceClass.allCases) { deviceClass in
                CoverCard(viewModel: CoverCardViewModel.mock(state: isOpen ? .open : .closed, deviceClass: deviceClass))
            }
        }
    }
    .padding(12)
}

fileprivate extension CoverCardViewModel {
    static func mock(state: CoverEntity.State,
                     position: Int? = nil,
                     deviceClass: CoverEntity.DeviceClass = .unknown) -> CoverCardViewModel {
        let cover = CoverEntity(entityId: "id",
                                name: deviceClass.rawValue,
                                state: state,
                                currentPosition: position,
                                deviceClass: deviceClass)
        return CoverCardViewModel(cover: cover, controller: MockCoverControlling())
    }
}

@MainActor
struct MockCoverControlling: CoverControlling {
    func setPosition(of id: String, to position: Int) async {

    }

    func openCover(_ id: String) async {

    }

    func closeCover(_ id: String) async {

    }

    func stopCover(_ id: String) async {

    }

    func toggleCover(_ id: String) async {

    }
}
#endif
