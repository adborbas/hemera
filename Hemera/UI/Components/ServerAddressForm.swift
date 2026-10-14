import SwiftUI
import Mortar

/**
 Shared address input for the two places a Home Assistant address is typed: onboarding
 and settings.

 Deliberately owns only the field, help text and error — the two screens commit in
 different ways (onboarding launches an OAuth flow from a prominent button, settings
 commits a value from a nav bar button), so action placement belongs to the caller.
*/
struct ServerAddressForm: View {

    @Binding var text: String
    let mode: ServerAddressMode
    let errorMessage: String?
    let onSubmit: () -> Void

    @FocusState private var isAddressFieldFocused: Bool

    var body: some View {
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
        // Typing is the only reason either screen opens, so skip the extra tap.
        .onAppear { isAddressFieldFocused = true }
    }
}

// MARK: - Localization

private extension ServerAddressForm {
    enum Localization {
        static let serverAddress = String(localized: "Server Address", comment: "Label for the server URL input field")
        static let urlPlaceholder = "http://homeassistant.local:8123"
    }
}
