import SwiftUI
import Mortar

struct SessionExpiredView: View {

    @State var viewModel = SessionExpiredViewModel()
    @State private var isExchangingToken = false

    var body: some View {
        VStack(spacing: Mortar.Spacing.xxl) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: Mortar.IconSize.m))
                .foregroundStyle(.secondary)

            Text(Localization.title)
                .font(.title2.bold())

            Text(Localization.body(viewModel.serverHost))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Mortar.PanelSpacing.edge)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Mortar.PanelSpacing.edge)
            }

            VStack(spacing: Mortar.Spacing.m) {
                Button(Localization.logIn) {
                    viewModel.logIn()
                }
                .buttonStyle(.mortarPrimary())

                Button(Localization.logOut) {
                    viewModel.showLogOutConfirmation = true
                }
                .buttonStyle(.mortarSecondary())
            }

            Spacer()
        }
        .alert(Localization.logOutQuestion(viewModel.serverHost), isPresented: $viewModel.showLogOutConfirmation) {
            Button(Localization.logOut, role: .destructive) {
                viewModel.confirmLogOut()
            }
            Button(Localization.cancel, role: .cancel) {}
        }
        .sheet(item: $viewModel.authSession, onDismiss: {
            viewModel.cancelAuth()
        }) { session in
            NavigationStack {
                OAuthWebView(
                    url: session.authorizeURL,
                    redirectURI: session.redirectURI,
                    onCallback: { callbackURL in
                        isExchangingToken = true
                        Task {
                            await viewModel.handleOAuthCallback(url: callbackURL, session: session)
                            isExchangingToken = false
                            viewModel.authSession = nil
                        }
                    },
                    onFailure: { viewModel.authSessionFailed() }
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
                        Button(Localization.cancel) {
                            viewModel.cancelAuth()
                        }
                        .opacity(isExchangingToken ? 0 : 1)
                    }
                }
            }
        }
    }
}

private extension SessionExpiredView {
    enum Localization {
        static let title = String(localized: "Session expired", comment: "Title shown when Home Assistant no longer accepts the saved login")
        static let logIn = String(localized: "Log In", comment: "Button that opens the Home Assistant login page to start a new session")
        static let logOut = String(localized: "Log Out", comment: "Button that logs out and removes the Home, theme and settings")
        static let cancel = String(localized: "Cancel", comment: "Button that dismisses the login page or the log out confirmation")

        static func body(_ host: String) -> String {
            String(
                localized: "Log in to \(host) again to carry on. Your Home and settings are kept.",
                comment: "Explanation on the Session expired screen, with the server hostname"
            )
        }

        static func logOutQuestion(_ host: String) -> String {
            String(localized: "Log out of \(host)?", comment: "Alert title confirming logout from the Session expired screen, with the server hostname")
        }
    }
}
