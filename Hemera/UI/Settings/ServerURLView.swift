import SwiftUI
import Mortar

/**
 Pushed detail editor, matching how iOS settings hierarchies edit a value: back discards,
 the trailing Save commits. Shares its input with onboarding via `ServerAddressForm`.
*/
struct ServerURLView: View {

    @State var viewModel: ServerURLViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Mortar.Spacing.xl) {
            ServerAddressForm(
                text: $viewModel.urlText,
                footer: Localization.footer,
                errorMessage: viewModel.errorMessage,
                onSubmit: save
            )

            Spacer()
        }
        .padding(Mortar.Spacing.xl)
        .navigationTitle(Localization.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button(Localization.save, action: save)
                        .disabled(!viewModel.canSave)
                }
            }
        }
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave { dismiss() }
        }
    }

    private func save() {
        Task { await viewModel.save() }
    }
}

// MARK: - Localization

private extension ServerURLView {
    enum Localization {
        static let title = String(localized: "Server Address", comment: "Navigation title for the screen where the user changes the Home Assistant address")
        static let footer = String(
            localized: "Another address for the same Home Assistant — your local address at home, or a VPN or remote address when you're away. You'll stay signed in.",
            comment: "Help text below the server address field in settings, clarifying the address must point at the same Home Assistant the user is already signed in to"
        )
        static let save = String(localized: "Save", comment: "Button that validates and saves the new server address")
    }
}

// MARK: - Preview

#if DEBUG
private final class PreviewURLChanger: ServerURLChanging {
    func changeServerURL(to url: URL) async throws {}
}

#Preview {
    NavigationStack {
        ServerURLView(
            viewModel: ServerURLViewModel(
                currentURL: URL(string: "http://homeassistant.local:8123"),
                urlChanger: PreviewURLChanger()
            )
        )
    }
}
#endif
