import SwiftUI
import Mortar

/**
 Pushed rather than presented: it is a step within the onboarding stack, so it uses the
 stack's own back button. Connect stays a prominent full-width button — it is the primary
 action of a first-run screen, and it launches the OAuth flow rather than committing a value.
*/
struct ManualEntryView: View {

    @Bindable var viewModel: ServerSelectionViewModel

    var body: some View {
        VStack(spacing: Mortar.Spacing.xl) {
            ServerAddressForm(
                text: $viewModel.manualURL,
                footer: Localization.manualEntryFooter,
                errorMessage: viewModel.errorMessage,
                onSubmit: connect
            )

            Spacer()

            Button(action: connect) {
                HStack {
                    Text(Localization.connect)
                    if viewModel.isConnecting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .buttonStyle(.mortarPrimary(width: .fullWidth))
            .disabled(
                viewModel.manualURL.trimmingCharacters(in: .whitespaces).isEmpty
                || viewModel.isConnecting
            )
        }
        .padding(Mortar.Spacing.xl)
        .navigationTitle(Localization.enterManually)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.errorMessage = nil }
    }

    /**
     Stay on screen whether or not the attempt succeeds: a failure keeps its inline error
     visible, and a success presents the OAuth sheet over this view.
    */
    private func connect() {
        _ = viewModel.connectManual()
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        ManualEntryView(viewModel: .previewEmpty)
    }
}
#endif

// MARK: - Localization

private extension ManualEntryView {
    enum Localization {
        static let enterManually = String(localized: "Enter address manually", comment: "Navigation title for manual server address entry screen")
        static let manualEntryFooter = String(localized: "Enter your Home Assistant server URL, including the port if needed.", comment: "Help text below the server URL input field")
        static let connect = String(localized: "Connect", comment: "Button to connect to the server")
    }
}
