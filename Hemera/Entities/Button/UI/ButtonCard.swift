import SwiftUI
import Mortar

struct ButtonCard: View {
    var viewModel: ButtonCardViewModel
    @State private var isPressing = false
    @State private var showConfirmation = false

    var body: some View {
        EntityCard {
            CardIcon(
                iconName: viewModel.iconName,
                backgroundColor: viewModel.iconBackgroundColor
            ) {
                handleTap()
            }
        } label: {
            CardLabel(title: viewModel.name, subtitle: viewModel.subtitle)
        }
        .unavailableStyle(viewModel.isAvailable)
        .scaleEffect(isPressing ? 0.95 : 1.0)
        .animation(.spring(duration: Mortar.Motion.fast), value: isPressing)
        .alert(Localization.confirmTitle(viewModel.name), isPresented: $showConfirmation) {
            Button(viewModel.subtitle, role: .destructive) { performPress() }
            Button(Localization.cancel, role: .cancel) { }
        } message: {
            Text(Localization.confirmMessage(viewModel.name))
        }
    }

    private func handleTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if viewModel.requiresConfirmation {
            showConfirmation = true
        } else {
            performPress()
        }
    }

    private func performPress() {
        isPressing = true
        viewModel.press()

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isPressing = false
        }
    }
}

// MARK: - Localization

private extension ButtonCard {
    enum Localization {
        static func confirmTitle(_ name: String) -> String {
            String(localized: "\(name)?",
                   comment: "Alert title asking for confirmation before pressing a destructive button (e.g. 'Restart Router?')")
        }
        static func confirmMessage(_ name: String) -> String {
            String(localized: "Are you sure you want to press \(name)?",
                   comment: "Alert message asking for confirmation before pressing a destructive button")
        }
        static let cancel = String(localized: "Cancel",
            comment: "Button to dismiss the confirmation alert without pressing the button")
    }
}

#if DEBUG
#Preview {
    ButtonCard(viewModel: ButtonCardViewModel.mockRestart())
        .padding(12)
}

fileprivate extension ButtonCardViewModel {
    static func mockRestart() -> ButtonCardViewModel {
        let button = ButtonEntity(entityId: "button.restart_router", name: "Restart Router", deviceClass: .restart)
        return ButtonCardViewModel(button: button, controller: MockButtonControlling())
    }

}

private class MockButtonControlling: ButtonControlling {
    func pressButton(_ id: String) async {}
}
#endif
