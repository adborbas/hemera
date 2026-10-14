import SwiftUI

/// Owns the view model and the pop-on-success that a `navigationDestination` closure cannot.
struct ServerURLView: View {

    @State var viewModel: ServerURLViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ServerAddressView(
            text: $viewModel.urlText,
            mode: viewModel.mode,
            isBusy: viewModel.isSaving,
            canSubmit: viewModel.canSave,
            errorMessage: viewModel.errorMessage,
            placement: .toolbar,
            onSubmit: { Task { await viewModel.save() } }
        )
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave { dismiss() }
        }
    }
}

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
