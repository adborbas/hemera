import SwiftUI
import Mortar

struct CoverControlPanel: View {
    var viewModel: CoverCardViewModel
    @Binding var isPresented: Bool

    @State private var currentMode: CoverControlMode = .slider
    @State private var value: Double = 0

    private var supportedModes: [CoverControlMode] {
        viewModel.supportedControlModes
    }

    private var initialValue: Double {
        guard let position = viewModel.position else { return 0 }
        return Double(100 - position) / 100.0
    }

    // MARK: - Body

    var body: some View {
        EntityControlPanel(
            isPresented: $isPresented,
            title: viewModel.name,
            subtitle: viewModel.stateDescription
        ) {
            controlContent
        } footer: {
            PillPicker(
                options: supportedModes,
                selection: $currentMode,
                icon: { $0.iconName }
            )
            .opacity(supportedModes.count > 1 ? 1 : 0)
            .allowsHitTesting(supportedModes.count > 1)
        }
        .animation(Mortar.Motion.springBouncy, value: currentMode)
        .onAppear {
            value = initialValue
            if let preferred = viewModel.preferredControlMode,
               supportedModes.contains(preferred) {
                currentMode = preferred
            } else if let first = supportedModes.first {
                currentMode = first
            }
        }
        .onChange(of: currentMode) { _, newMode in
            viewModel.preferredControlMode = newMode
        }
        .onChange(of: viewModel.position) { _, _ in
            value = initialValue
        }
        .onChange(of: viewModel.supportedControlModes) { _, newModes in
            if !newModes.contains(currentMode), let first = newModes.first {
                currentMode = first
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var controlContent: some View {
        switch currentMode {
        case .slider:
            VerticalSlider(
                value: $value,
                configuration: .init(range: 0...1.0, style: .fill(.top))
            ) { value in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.setPosition(to: 100 - Int(value * 100))
            }
            .sliderFill(.blue)
            .frame(width: Mortar.ControlPanelSize.controlWidth)
            .transition(.blurReplace)

        case .buttons:
            CoverButtonStack(viewModel: viewModel)
                .transition(.blurReplace)
        }
    }
}

// MARK: - CoverButtonStack

private struct CoverButtonStack: View {
    var viewModel: CoverCardViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.supportsOpen {
                coverButton(icon: "triangle.fill", rotation: 0) {
                    viewModel.open()
                }
            }
            if viewModel.supportsOpen && (viewModel.supportsStop || viewModel.supportsClose) {
                Divider()
            }
            if viewModel.supportsStop {
                coverButton(icon: "stop.fill", rotation: 0) {
                    viewModel.stop()
                }
            }
            if viewModel.supportsStop && viewModel.supportsClose {
                Divider()
            }
            if viewModel.supportsClose {
                coverButton(icon: "triangle.fill", rotation: 180) {
                    viewModel.close()
                }
            }
        }
        .frame(width: Mortar.ControlPanelSize.controlWidth)
        .background(
            RoundedRectangle(cornerRadius: Mortar.Radii.xl, style: .continuous)
                .fill(PlatformColor.systemGray5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Mortar.Radii.xl, style: .continuous))
    }

    private func coverButton(
        icon: String,
        rotation: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            Image(systemName: icon)
                .font(.title2)
                .rotationEffect(.degrees(rotation))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(CoverButtonPressStyle())
    }
}

// MARK: - CoverButtonPressStyle

private struct CoverButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.primary.opacity(0.1) : Color.clear)
    }
}
