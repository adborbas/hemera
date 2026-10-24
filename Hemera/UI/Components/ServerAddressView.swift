import SwiftUI
import Mortar

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

    @State var handler: any ServerAddressHandling
    let placement: ServerAddressActionPlacement
    /// Called once the address is accepted. What that means is the caller's business.
    var onFinished: () -> Void = {}

    @FocusState private var isAddressFieldFocused: Bool

    var body: some View {
        VStack(spacing: Mortar.Spacing.xl) {
            inputSection

            Spacer()

            if placement == .prominent {
                Button(action: submit) {
                    HStack {
                        Text(handler.mode.actionTitle)
                        if handler.isBusy {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .buttonStyle(.mortarPrimary(width: .fullWidth))
                .disabled(!handler.canSubmit || handler.isBusy)
            }
        }
        .padding(Mortar.Spacing.xl)
        .navigationTitle(handler.mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if placement == .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if handler.isBusy {
                        ProgressView()
                    } else {
                        Button(handler.mode.actionTitle, action: submit)
                            .disabled(!handler.canSubmit)
                    }
                }
            }
        }
        // Typing is the only reason this screen opens, so skip the extra tap.
        .onAppear { isAddressFieldFocused = true }
    }

    private func submit() {
        // The Return key reaches here too, where no `.disabled` applies.
        guard handler.canSubmit, !handler.isBusy else { return }
        Task {
            if await handler.submit() {
                onFinished()
            } else {
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

            TextField(Localization.urlPlaceholder, text: $handler.text)
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

            if let footer = handler.mode.footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, Mortar.Spacing.xs)
            }

            if let errorMessage = handler.errorMessage {
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
        /// No scheme: it is optional now, and showing http would advertise the unencrypted one.
        static let urlPlaceholder = "homeassistant.local:8123"
    }
}
