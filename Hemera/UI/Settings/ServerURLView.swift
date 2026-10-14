import SwiftUI

/// Owns the view model, which a `navigationDestination` closure cannot.
struct ServerURLView: View {

    @State var viewModel: ServerURLViewModel

    var body: some View {
        ServerAddressView(
            text: $viewModel.urlText,
            mode: viewModel.mode,
            isBusy: viewModel.isSaving,
            canSubmit: viewModel.canSave,
            errorMessage: viewModel.errorMessage,
            placement: .toolbar,
            handler: viewModel
        )
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
