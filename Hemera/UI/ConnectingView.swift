import SwiftUI
import Mortar

struct ConnectingView: View {

    @Bindable var viewModel: ConnectingViewModel
    @Environment(ScreenManager.self) private var screenManager
    @State private var settingsInitialRoute: SettingsViewModel.Route?

    var body: some View {
        VStack(spacing: Mortar.Spacing.xxl) {
            Spacer()

            if viewModel.timedOut {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text(Localization.unableToConnect)
                    .font(.title2.bold())

                Text(Localization.couldNotReach(viewModel.serverHost))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Mortar.PanelSpacing.edge)

                Button(Localization.retry) {
                    viewModel.retry()
                }
                .buttonStyle(.mortarPrimary())
            } else {
                ProgressView()
                    .controlSize(.large)

                Text(Localization.connecting(viewModel.serverHost))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(Localization.settings) {
                viewModel.showSettings = true
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, Mortar.PanelSpacing.edge)
        }
        .onAppear { viewModel.startTimeout() }
        .onDisappear { viewModel.cancelTimeout() }
        .sheet(isPresented: $viewModel.showSettings, onDismiss: {
            settingsInitialRoute = nil
            screenManager.acknowledgeSettingsDismissed()
        }) {
            SettingsView(viewModel: SettingsViewModel(initialRoute: settingsInitialRoute))
        }
        .onChange(of: screenManager.settingsRequest) { _, new in
            switch new {
            case .close:
                viewModel.showSettings = false
            case .openKioskMode:
                settingsInitialRoute = .kioskMode
                viewModel.showSettings = true
                screenManager.acknowledgeSettingsOpened()
            case .none:
                break
            }
        }
    }
}

private extension ConnectingView {
    enum Localization {
        static let unableToConnect = String(localized: "Unable to Connect", comment: "Title shown when the app cannot reach the Home Assistant server")
        static let retry = String(localized: "Retry", comment: "Button to retry connecting to the server")
        static let settings = String(localized: "Settings", comment: "Button to open the settings screen")

        static func couldNotReach(_ host: String) -> String {
            String(localized: "Could not reach \(host). Make sure you're on the same network as your Home Assistant server.", comment: "Error message shown when connection to the server times out, with the server hostname")
        }

        static func connecting(_ host: String) -> String {
            String(localized: "Connecting to \(host)...", comment: "Loading status shown while establishing connection to the server, with the server hostname")
        }
    }
}
