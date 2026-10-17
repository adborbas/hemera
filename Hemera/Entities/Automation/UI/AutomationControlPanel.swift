import SwiftUI
import Mortar

struct AutomationControlPanel: View {
    var viewModel: AutomationCardViewModel
    @Binding var isPresented: Bool
    @State private var isTriggering = false

    var body: some View {
        EntityControlPanel(isPresented: $isPresented,
                          title: viewModel.name,
                          subtitle: lastTriggeredText) {
            Button {
                triggerAutomation()
            } label: {
                Label(Localization.trigger, systemImage: "play.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 16))
            }
            .opacity(isTriggering ? 0.6 : 1.0)
            .animation(.easeInOut(duration: Mortar.Motion.fast), value: isTriggering)
        }
    }

    private var lastTriggeredText: String {
        guard let date = viewModel.lastTriggered else {
            return Localization.neverTriggered
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return String(localized: "Last triggered \(formatter.localizedString(for: date, relativeTo: Date()))",
                      comment: "Automation control panel subtitle showing when the automation last ran")
    }

    private func triggerAutomation() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isTriggering = true
        viewModel.trigger()

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isTriggering = false
        }
    }
}

private extension AutomationControlPanel {
    enum Localization {
        static let trigger = String(localized: "Trigger", comment: "Button label to manually trigger an automation")
        static let neverTriggered = String(localized: "Never triggered", comment: "Automation control panel subtitle when the automation has never been triggered")
    }
}

#if DEBUG
#Preview {
    AutomationControlPanel(
        viewModel: AutomationCardViewModel(
            automation: AutomationEntity(
                entityId: "automation.motion_lights",
                name: "Motion Lights",
                state: .on,
                lastTriggered: Date().addingTimeInterval(-300)
            ),
            controller: PreviewAutomationController()
        ),
        isPresented: .constant(true)
    )
}

private class PreviewAutomationController: AutomationControlling {
    func setAutomation(_ id: String, on: Bool) async {}
    func triggerAutomation(_ id: String) async {}
}
#endif
