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

    @Binding var text: String
    let mode: ServerAddressMode
    let isBusy: Bool
    let canSubmit: Bool
    let errorMessage: String?
    let placement: ServerAddressActionPlacement
    let onSubmit: () -> Void

    @FocusState private var isAddressFieldFocused: Bool

    var body: some View {
        VStack(spacing: Mortar.Spacing.xl) {
            inputSection

            Spacer()

            if placement == .prominent {
                Button(action: onSubmit) {
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
                        Button(mode.actionTitle, action: onSubmit)
                            .disabled(!canSubmit)
                    }
                }
            }
        }
        // Typing is the only reason this screen opens, so skip the extra tap.
        .onAppear { isAddressFieldFocused = true }
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
                .onSubmit(onSubmit)

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
