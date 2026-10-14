import SwiftUI
import Mortar

/**
 Pushed rather than presented: a step within the onboarding stack, so it uses the stack's
 back button. Connect stays a prominent full-width button — it is the primary action of a
 first-run screen, and it launches the OAuth flow rather than committing a value.
*/
struct ManualEntryView: View {

    @Bindable var viewModel: ServerSelectionViewModel

    private let mode = ServerAddressMode.initial

    var body: some View {
        VStack(spacing: Mortar.Spacing.xl) {
            ServerAddressForm(
                text: $viewModel.manualURL,
                mode: mode,
                errorMessage: viewModel.errorMessage,
                onSubmit: connect
            )

            Spacer()

            Button(action: connect) {
                HStack {
                    Text(mode.actionTitle)
                    if viewModel.isConnecting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .buttonStyle(.mortarPrimary(width: .fullWidth))
            .disabled(!viewModel.canConnect)
        }
        .padding(Mortar.Spacing.xl)
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.errorMessage = nil }
    }

    /**
     Stay on screen whether or not the attempt succeeds: a failure keeps its inline error
     visible, and a success presents the OAuth sheet over this view.
    */
    private func connect() {
        viewModel.connectManual()
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
