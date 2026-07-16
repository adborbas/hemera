import SwiftUI
import Mortar

struct ManualEntrySheet: View {

    @Bindable var viewModel: ServerSelectionViewModel
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Mortar.Spacing.xl) {
                VStack(alignment: .leading, spacing: Mortar.Spacing.s) {
                    Text(Localization.serverAddress)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, Mortar.Spacing.xs)

                    TextField(Localization.urlPlaceholder, text: $viewModel.manualURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .padding(Mortar.Spacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: Mortar.Radii.s, style: .continuous)
                                .fill(Color(.tertiarySystemBackground))
                        )
                        .onSubmit { connectAndDismiss() }

                    Text(Localization.manualEntryFooter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, Mortar.Spacing.xs)
                }

                Button {
                    connectAndDismiss()
                } label: {
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

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Color.error)
                        .font(.caption)
                }

                Spacer()
            }
            .padding(Mortar.Spacing.xl)
            .navigationTitle(Localization.enterManually)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Localization.cancel) {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onDisappear { viewModel.errorMessage = nil }
    }

    private func connectAndDismiss() {
        if viewModel.connectManual() {
            onDismiss()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ManualEntrySheet(viewModel: .previewEmpty) {}
}
#endif

// MARK: - Localization

private extension ManualEntrySheet {
    enum Localization {
        static let enterManually = String(localized: "Enter address manually", comment: "Navigation title for manual server address entry sheet")
        static let serverAddress = String(localized: "Server Address", comment: "Label for the server URL input field")
        static let urlPlaceholder = "http://homeassistant.local:8123"
        static let manualEntryFooter = String(localized: "Enter your Home Assistant server URL, including the port if needed.", comment: "Help text below the server URL input field")
        static let connect = String(localized: "Connect", comment: "Button to connect to the server")
        static let cancel = String(localized: "Cancel", comment: "Button to cancel manual entry sheet")
    }
}
