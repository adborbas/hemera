import SwiftUI
import Mortar

struct ScriptCard: View {
    var viewModel: ScriptCardViewModel

    var body: some View {
        EntityCard(tintColor: viewModel.tintColor, isActive: viewModel.isRunning) {
            CardIcon(
                iconName: viewModel.isRunning ? "stop.fill" : viewModel.iconName,
                backgroundColor: viewModel.tintColor
            ) {
                viewModel.performPrimaryAction()
            }
        } label: {
            CardLabel(
                title: viewModel.name,
                subtitle: viewModel.isRunning ? Localization.running : Localization.script
            )
        }
        .unavailableStyle(viewModel.isAvailable)
        .animation(Mortar.Motion.springNormal, value: viewModel.isRunning)
    }
}

private extension ScriptCard {
    enum Localization {
        static let script = String(localized: "Script", comment: "Entity type label shown on an idle script card")
        static let running = String(localized: "Running…", comment: "Subtitle shown on a script (action) card while the script is executing")
    }
}

#if DEBUG
#Preview {
    VStack {
        ScriptCard(viewModel: ScriptCardViewModel.mockScript())
    }
    .padding(12)
}

fileprivate extension ScriptCardViewModel {
    static func mockScript() -> ScriptCardViewModel {
        let script = ScriptEntity(entityId: "script.movie_time", name: "Movie Time")
        return ScriptCardViewModel(script: script, controller: MockScriptControlling())
    }
}

private class MockScriptControlling: ScriptControlling {
    func runScript(_ id: String) async {}
    func cancelScript(_ id: String) async {}
}
#endif
