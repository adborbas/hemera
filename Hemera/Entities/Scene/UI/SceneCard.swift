import SwiftUI
import Mortar

struct SceneCard: View {
    var viewModel: SceneCardViewModel
    @State private var isActivating = false

    var body: some View {
        EntityCard {
            CardIcon(
                icon: isActivating ? "mdi:check-circle" : viewModel.iconName,
                backgroundColor: isActivating ? .green : .purple,
                actionLabel: viewModel.isAvailable ? Localization.activate : nil
            ) {
                activateScene()
            }
            .accessibilityIdentifier("\(viewModel.id).icon")
        } label: {
            CardLabel(title: viewModel.name, subtitle: Localization.scene, accessibilityIdentifier: viewModel.id)
        }
        .unavailableStyle(viewModel.isAvailable)
        .animation(.easeInOut(duration: Mortar.Motion.fast), value: isActivating)
    }

    private func activateScene() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isActivating = true
        viewModel.activate()

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isActivating = false
        }
    }
}

private extension SceneCard {
    enum Localization {
        static let scene = String(localized: "Scene", comment: "Entity type label shown on a scene card")
        static let activate = String(localized: "Activate", comment: "VoiceOver name for the card icon that activates the scene")
    }
}

#if DEBUG
#Preview {
    VStack {
        SceneCard(viewModel: SceneCardViewModel.mockScene())
    }
    .padding(12)
}

fileprivate extension SceneCardViewModel {
    static func mockScene() -> SceneCardViewModel {
        let scene = SceneEntity(entityId: "scene.movie_time", name: "Movie Time")
        return SceneCardViewModel(scene: scene, controller: MockSceneControlling())
    }
}

private class MockSceneControlling: SceneControlling {
    func activateScene(_ id: String) async {}
}
#endif
