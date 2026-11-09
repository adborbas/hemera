import SwiftUI
import Mortar

struct VacuumControlPanel: View {
    var viewModel: VacuumCardViewModel
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        EntityControlPanel(
            isPresented: $isPresented,
            title: viewModel.name,
            subtitle: viewModel.stateDescription
        ) {
            VStack(spacing: Mortar.Spacing.xxl) {
                batteryLine
                VacuumRobot(
                    state: viewModel.state,
                    motion: viewModel.robotMotion(reduceMotion: reduceMotion),
                    icon: viewModel.iconName,
                    tint: viewModel.tintColor,
                    size: Constants.robotSize
                )
                buttons
            }
        }
        .animation(Mortar.Motion.springNormal, value: viewModel.state)
    }

    // MARK: - Battery

    @ViewBuilder
    private var batteryLine: some View {
        if let icon = viewModel.batteryIconName, let level = viewModel.batteryDescription {
            HStack(spacing: Mortar.Spacing.xs) {
                MDIIcon(name: icon, size: Mortar.IconSize.xs)
                Text(level)
            }
            .font(.headline)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Localization.battery)
            .accessibilityValue(level)
        }
    }

    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: Mortar.Spacing.m) {
            ForEach(viewModel.panelButtons) { button in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.perform(button.action)
                } label: {
                    CircleIconLabel(mdiIcon: button.action.iconName, color: .primary)
                }
                .buttonStyle(.plain)
                .disabled(!button.isEnabled)
                .opacity(button.isEnabled ? 1 : Constants.disabledOpacity)
                .accessibilityLabel(button.action.label)
            }
        }
    }
}

// MARK: - Robot

/// The robot drawn in its state's look. Decoration only: the subtitle already says the state.
private struct VacuumRobot: View {
    let state: VacuumEntity.State
    let motion: VacuumCardViewModel.RobotMotion?
    let icon: String?
    let tint: Color
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(paused: motion == nil)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                if motion == .errorPulse { errorGlow(time) }
                if motion == .headingHome { chevrons(time) }
                robot
                    .rotationEffect(.degrees(rotation(time)))
                    .offset(offset(time))
            }
            // Room for the dock and the motion; offsets never change the layout.
            .frame(width: size * Constants.canvasScale, height: size * Constants.canvasScale)
        }
        .opacity(state == .unavailable ? Constants.unavailableOpacity : 1)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var robot: some View {
        if state == .docked {
            dockedRobot
        } else {
            MDIIcon(name: icon ?? Constants.robotIcon, fallback: Constants.robotIcon, size: size)
                .foregroundStyle(color)
        }
    }

    private var color: Color {
        switch state {
        case .cleaning, .returning, .error: tint
        case .paused: tint.opacity(Constants.pausedTintOpacity)
        case .docked, .idle, .unknown, .unavailable: .secondary
        }
    }

    // The robot's lower edge is cut away where it sits inside the dock, as in HA's illustration.
    private var dockedRobot: some View {
        ZStack {
            Image(.robotVacuumOutline)
                .resizable()
                .frame(width: size, height: size)
                .foregroundStyle(color)
                .mask {
                    Rectangle()
                        .overlay { atDock(dockShape.fill(.black)).blendMode(.destinationOut) }
                        .compositingGroup()
                }
            atDock(dockShape.strokeBorder(Color.secondary.opacity(Constants.dockBorderOpacity), lineWidth: size * 0.025))
        }
    }

    // MARK: - Motion

    private func rotation(_ time: Double) -> Double {
        motion == .wander ? sin(time * 0.6) * 18 : 0
    }

    private func offset(_ time: Double) -> CGSize {
        switch motion {
        case .wander: CGSize(width: sin(time * 0.7) * size * 0.06, height: sin(time * 1.1) * size * 0.04)
        case .headingHome: CGSize(width: 0, height: size * (0.08 + sin(time * 6) * 0.01))
        case .errorPulse, nil: .zero
        }
    }

    // Lit one after another, so they read as heading forward.
    private func chevrons(_ time: Double) -> some View {
        ForEach(0..<3, id: \.self) { index in
            let lit = max(0, sin(time * 4 - Double(index) * 0.9))
            Image(systemName: "chevron.up")
                .font(.system(size: size * 0.12, weight: .bold))
                .foregroundStyle(tint.opacity(0.2 + 0.8 * lit))
                .offset(y: -size * (0.48 + 0.1 * Double(index)))
        }
    }

    private func errorGlow(_ time: Double) -> some View {
        let pulse = 0.5 + 0.5 * sin(time * 2 * .pi / Constants.errorPulsePeriod)
        return Circle()
            .fill(RadialGradient(colors: [tint, .clear], center: .center, startRadius: 0, endRadius: size * 0.7))
            .opacity(0.08 + 0.27 * pulse)
            .frame(width: size * Constants.canvasScale, height: size * Constants.canvasScale)
    }

    private var dockShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
    }

    // Placed relative to the robot's centre, so the cut-out and the drawn dock line up.
    private func atDock(_ dock: some View) -> some View {
        dock
            .frame(width: size * 0.62, height: size * 0.2)
            .offset(y: size * 0.47)
    }
}

// MARK: - Constants

private enum Constants {
    static let robotSize: CGFloat = 230
    static let robotIcon = "mdi:robot-vacuum"
    static let canvasScale: CGFloat = 1.4
    static let disabledOpacity = 0.4
    static let pausedTintOpacity = 0.45
    static let unavailableOpacity = 0.35
    static let dockBorderOpacity = 0.55
    static let errorPulsePeriod = 1.8
}

// MARK: - Localization

private extension VacuumControlPanel {
    enum Localization {
        static let battery = String(localized: "Battery", comment: "VoiceOver label for the robot vacuum's battery level in its control panel")
    }
}

#if DEBUG
#Preview("Docked") {
    VacuumControlPanel(viewModel: .previewMock(state: .docked), isPresented: .constant(true))
}

#Preview("Cleaning") {
    VacuumControlPanel(viewModel: .previewMock(state: .cleaning), isPresented: .constant(true))
}

fileprivate extension VacuumCardViewModel {
    static func previewMock(state: VacuumEntity.State) -> VacuumCardViewModel {
        let features: VacuumEntity.Features = [.start, .pause, .stop, .returnHome, .locate]
        let vacuum = VacuumEntity(entityId: "vacuum.robot", name: "Robot Vacuum", state: state, supportedFeaturesRaw: features.rawValue)
        return VacuumCardViewModel(vacuum: vacuum, controller: PreviewVacuumControlling())
    }
}

private struct PreviewVacuumControlling: VacuumControlling {
    func startVacuum(_ id: String) async {}
    func pauseVacuum(_ id: String) async {}
    func stopVacuum(_ id: String) async {}
    func returnVacuumToBase(_ id: String) async {}
    func locateVacuum(_ id: String) async {}
}
#endif
