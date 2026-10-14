import SwiftUI
import Mortar

/**
 Pushed detail editor, matching how iOS settings hierarchies edit a value: back discards,
 the trailing action commits.
*/
struct ServerURLView: View {

    @State var viewModel: ServerURLViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Mortar.Spacing.xl) {
            ServerAddressForm(
                text: $viewModel.urlText,
                mode: viewModel.mode,
                errorMessage: viewModel.errorMessage,
                onSubmit: save
            )

            Spacer()
        }
        .padding(Mortar.Spacing.xl)
        .navigationTitle(viewModel.mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button(viewModel.mode.actionTitle, action: save)
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

// MARK: - Preview

#if DEBUG
private final class PreviewURLChanger: ServerURLChanging {
    func changeServerURL(to url: URL) async throws {}
}

#Preview {
    NavigationStack {
        ServerURLView(
            viewModel: ServerURLViewModel(
                mode: .edit(current: URL(string: "http://homeassistant.local:8123")!),
                urlChanger: PreviewURLChanger()
            )
        )
    }
}
#endif
