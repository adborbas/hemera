import SwiftUI
import Mortar

struct DemoModeBanner: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: DemoModeBannerViewModel

    var body: some View {
        Section {
            VStack(spacing: Mortar.Spacing.l) {
                Label {
                    VStack(alignment: .leading, spacing: Mortar.Spacing.xs) {
                        Text(Localization.demoModeActive)
                            .font(.headline)
                        Text(Localization.demoModeDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.warning)
                        .font(.title2)
                }

                VStack(spacing: Mortar.Spacing.s) {
                    Button {
                        dismiss()
                        viewModel.connect()
                    } label: {
                        Text(Localization.connectToHA)
                    }
                    .buttonStyle(.mortarPrimary(width: .fullWidth))
                    Button {
                        viewModel.exitDemoTapped()
                    } label: {
                        Text(Localization.exitDemo)
                    }
                    .buttonStyle(.mortarDestructive(width: .fullWidth))
                }
            }
            .padding(Mortar.Spacing.l)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Mortar.Radii.s))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Mortar.Spacing.s, leading: Mortar.Spacing.l, bottom: Mortar.Spacing.s, trailing: Mortar.Spacing.l))
        }
        .alert(Localization.exitDemoQuestion, isPresented: $viewModel.showExitDemoConfirmation) {
            Button(Localization.exitDemo, role: .destructive) {
                dismiss()
                viewModel.confirmExitDemo()
            }
            Button(Localization.cancel, role: .cancel) {}
        } message: {
            Text(Localization.exitDemoMessage)
        }
    }
}

private extension DemoModeBanner {
    enum Localization {
        static let demoModeActive = String(localized: "Demo Mode Active", comment: "Header label shown in settings when the app is running in demo mode")
        static let demoModeDescription = String(localized: "You are using simulated data. Connect to a Home Assistant server for full functionality.", comment: "Description shown in settings explaining the app is in demo mode")
        static let connectToHA = String(localized: "Connect to Home Assistant", comment: "Button in demo mode settings to navigate to server connection")
        static let exitDemo = String(localized: "Exit Demo", comment: "Destructive button to leave demo mode")
        static let exitDemoQuestion = String(localized: "Exit Demo?", comment: "Alert title confirming exit from demo mode")
        static let exitDemoMessage = String(localized: "Return to the welcome screen to connect to your Home Assistant server.", comment: "Alert message explaining what happens when exiting demo mode")
        static let cancel = String(localized: "Cancel", comment: "Button to cancel the current action")
    }
}
