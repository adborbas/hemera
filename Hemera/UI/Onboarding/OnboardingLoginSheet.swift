import SwiftUI
import Mortar

/// The Log in step: Home Assistant's own login page.
struct OnboardingLoginSheet: View {

    let session: OAuthFlowManager.AuthSession
    let onCallback: (URL) async -> Void
    let onFailure: () -> Void
    let onCancel: () -> Void

    @State private var isExchangingToken = false

    var body: some View {
        NavigationStack {
            OAuthWebView(
                url: session.authorizeURL,
                redirectURI: session.redirectURI,
                onCallback: { callbackURL in
                    isExchangingToken = true
                    Task {
                        await onCallback(callbackURL)
                        isExchangingToken = false
                    }
                },
                onFailure: onFailure
            )
            .ignoresSafeArea()
            .overlay {
                if isExchangingToken {
                    ZStack {
                        PlatformColor.systemBackground
                            .ignoresSafeArea()
                        ProgressView()
                            .controlSize(.large)
                    }
                }
            }
            .navigationTitle(Localization.logIn)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Localization.cancel, action: onCancel)
                        .opacity(isExchangingToken ? 0 : 1)
                }
            }
        }
    }
}

// MARK: - Localization

private extension OnboardingLoginSheet {
    enum Localization {
        static let logIn = String(localized: "Log In", comment: "Title of the sheet showing Home Assistant's login page during onboarding")
        static let cancel = String(localized: "Cancel", comment: "Button closing the login sheet without logging in")
    }
}
