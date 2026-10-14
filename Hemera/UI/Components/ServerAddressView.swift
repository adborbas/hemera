import SwiftUI
import Mortar

/// What a submission turned out to be, so the screen can react without knowing which task it is.
enum ServerAddressSubmitResult {
    /// The address was accepted and there is nothing left to do here.
    case finished
    /// Accepted, but the work carries on elsewhere — onboarding hands over to the OAuth flow.
    case continued
    /// Rejected; the handler is now showing why.
    case failed
}

/**
 What happens when an address is submitted.

 The two screens diverge entirely here — onboarding starts an OAuth flow, settings validates
 the address and persists it — so each reports what became of the attempt rather than the
 view inferring it.
*/
@MainActor
protocol ServerAddressSubmitting {
    func submit() async -> ServerAddressSubmitResult
}

/// Where the commit action sits — a presentation choice, not a behavioural one.
enum ServerAddressActionPlacement: Equatable {
    /// Full-width button at the bottom: the primary action of a first-run screen.
    case prominent
    /// Trailing nav bar button: committing a value in a settings hierarchy.
    case toolbar
}

/**
 The one screen for typing a Home Assistant address, used by onboarding and settings.

 Takes plain values rather than a view model: the two callers have very different ones
 (onboarding's also owns discovery, the OAuth session and the HTTP warning), and what this
 screen needs from them is identical.
*/
struct ServerAddressView: View {

    @Binding var text: String
    let mode: ServerAddressMode
    let isBusy: Bool
    let canSubmit: Bool
    let errorMessage: String?
    let placement: ServerAddressActionPlacement
    let handler: any ServerAddressSubmitting

    @FocusState private var isAddressFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Mortar.Spacing.xl) {
            inputSection

            Spacer()

            if placement == .prominent {
                Button(action: submit) {
                    HStack {
                        Text(mode.actionTitle)
                        if isBusy {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .buttonStyle(.mortarPrimary(width: .fullWidth))
                .disabled(!canSubmit || isBusy)
            }
        }
        .padding(Mortar.Spacing.xl)
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if placement == .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isBusy {
                        ProgressView()
                    } else {
                        Button(mode.actionTitle, action: submit)
                            .disabled(!canSubmit)
                    }
                }
            }
        }
        // Typing is the only reason this screen opens, so skip the extra tap.
        .onAppear { isAddressFieldFocused = true }
    }

    private func submit() {
        Task {
            switch await handler.submit() {
            case .finished:
                dismiss()
            case .continued:
                break
            case .failed:
                // Put the cursor back so the address can be corrected without tapping in again.
                isAddressFieldFocused = true
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: Mortar.Spacing.s) {
            Text(Localization.serverAddress)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, Mortar.Spacing.xs)

            TextField(Localization.urlPlaceholder, text: $text)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .focused($isAddressFieldFocused)
                .padding(Mortar.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: Mortar.Radii.s, style: .continuous)
                        .fill(PlatformColor.tertiarySystemBackground)
                )
                .onSubmit(submit)

            Text(mode.footer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, Mortar.Spacing.xs)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.error)
                    .font(.caption)
                    .padding(.leading, Mortar.Spacing.xs)
            }
        }
    }
}

// MARK: - Localization

private extension ServerAddressView {
    enum Localization {
        static let serverAddress = String(localized: "Server Address", comment: "Label for the server URL input field")
        static let urlPlaceholder = "http://homeassistant.local:8123"
    }
}
