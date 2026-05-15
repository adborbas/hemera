import SwiftUI

struct HAWebViewCover: ViewModifier {
    @Bindable var presenter: HAWebViewPresenter

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $presenter.isPresented) {
                if let url = presenter.url {
                    NavigationStack {
                        AuthenticatedWebView(url: url) {
                            try await presenter.validAccessToken()
                        }
                        .ignoresSafeArea()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(Localization.done) { presenter.dismiss() }
                            }
                        }
                    }
                }
            }
    }
}

extension View {
    func haWebViewCover(presenter: HAWebViewPresenter) -> some View {
        modifier(HAWebViewCover(presenter: presenter))
    }
}

private extension HAWebViewCover {
    enum Localization {
        static let done = String(
            localized: "Done",
            comment: "Button to dismiss the Home Assistant web view"
        )
    }
}
