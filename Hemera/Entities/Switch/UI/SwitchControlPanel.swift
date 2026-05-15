import SwiftUI
import Mortar

struct SwitchControlPanel: View {
    var viewModel: SwitchCardViewModel
    @Binding var isPresented: Bool

    @State private var isOn: Bool = false
    @State private var isPressed: Bool = false

    var body: some View {
        EntityControlPanel(
            isPresented: $isPresented,
            title: viewModel.name,
            subtitle: subtitle
        ) {
            powerButton
        }
        .onAppear { isOn = viewModel.isOn }
        .onChange(of: viewModel.isOn) { _, newValue in
            withAnimation(Mortar.Motion.springBouncy) {
                isOn = newValue
            }
        }
    }

    // MARK: - Subtitle

    private var subtitle: String {
        isOn ? Localization.on : Localization.off
    }

    // MARK: - Power Button

    private var powerButton: some View {
        Button {
            toggleState()
        } label: {
            ZStack {
                Circle()
                    .fill(isOn ? Color.green : PlatformColor.systemGray5)
                    .animation(Mortar.Motion.springBouncy, value: isOn)

                Circle()
                    .strokeBorder(isOn ? Color.green.opacity(0.3) : PlatformColor.systemGray4, lineWidth: 4)
                    .animation(Mortar.Motion.springBouncy, value: isOn)

                Image(systemName: viewModel.iconName)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(isOn ? .white : PlatformColor.systemGray2)
                    .animation(Mortar.Motion.springBouncy, value: isOn)
            }
            .frame(width: Constants.buttonSize, height: Constants.buttonSize)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(Mortar.Motion.springBouncy, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    // MARK: - Actions

    private func toggleState() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let newState = !isOn
        withAnimation(Mortar.Motion.springBouncy) {
            isOn = newState
        }
        viewModel.setOn(newState)
    }
}

// MARK: - Constants

private extension SwitchControlPanel {
    enum Constants {
        static let buttonSize: CGFloat = 160
    }
}

// MARK: - Localization

private extension SwitchControlPanel {
    enum Localization {
        static let on = String(localized: "On", comment: "Switch control panel subtitle when the switch is turned on")
        static let off = String(localized: "Off", comment: "Switch control panel subtitle when the switch is turned off")
    }
}
