import SwiftUI
import Mortar

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

struct SettingsView: View {

    enum PresentationContext {
        case sheet
        case tab
    }

    @Bindable var viewModel: SettingsViewModel
    let presentationContext: PresentationContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ScreenManager.self) private var screenManager

    init(viewModel: SettingsViewModel, presentationContext: PresentationContext = .sheet) {
        self.viewModel = viewModel
        self.presentationContext = presentationContext
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            List {
                demoModeHeader
                    .renderIf(viewModel.isShowingDemoModeHeader)
                serverInfoSection
                    .renderIf(viewModel.isShowingServerInfoSection)
                kioskModeSection
                aboutSection
                logoutSection
                    .renderIf(viewModel.isShowingLogoutSection)
            }
            .task {
                viewModel.navigateToPendingRoute()
                if !viewModel.isDemoMode {
                    await viewModel.fetchHAVersion()
                }
            }
            .navigationDestination(for: SettingsViewModel.Route.self) { route in
                switch route {
                case .kioskMode:
                    KioskModeView(screenManager: viewModel.screenManager)
                }
            }
            .navigationTitle(Localization.settings)
            .toolbar {
                if presentationContext == .sheet {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: {
                            Label(Localization.close, systemImage: "xmark")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $viewModel.showServerWebView) {
                if let url = viewModel.serverURL {
                    NavigationStack {
                        AuthenticatedWebView(url: url) {
                            try await viewModel.validAccessToken()
                        }
                        .ignoresSafeArea()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(Localization.done) { viewModel.closeServer() }
                            }
                        }
                    }
                }
            }
            .overlay {
                if viewModel.showConfetti {
                    ConfettiView {
                        viewModel.confettiFinished()
                    }
                    .allowsHitTesting(false)
                }
            }
            .alert(Localization.logOutQuestion, isPresented: $viewModel.showLogoutConfirmation) {
                Button(Localization.logOut, role: .destructive) {
                    viewModel.confirmLogout()
                    if presentationContext == .sheet { dismiss() }
                }
                Button(Localization.cancel, role: .cancel) {}
            } message: {
                if let host = viewModel.logoutHost {
                    Text(Localization.logOutMessageWithHost(host))
                } else {
                    Text(Localization.logOutMessage)
                }
            }
        }
        .interactiveDismissDisabled(presentationContext == .sheet)
    }

    private var demoModeHeader: some View {
        DemoModeBanner(viewModel: viewModel.bannerViewModel)
    }

    private var serverInfoSection: some View {
        Section(Localization.server) {
            if let url = viewModel.serverURL {
                LabeledContent(Localization.url, value: url.absoluteString)
                if let haVersion = viewModel.haVersion {
                    LabeledContent(Localization.version, value: haVersion)
                }
                Button {
                    viewModel.openServer()
                } label: {
                    HStack {
                        Text(Localization.openServer)
                        Spacer()
                        ExternalLinkIndicator()
                    }
                }
                .tint(.primary)
            }
        }
    }

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.logoutTapped()
            } label: {
                HStack {
                    Spacer()
                    Text(Localization.logOut)
                    Spacer()
                }
            }
        }
    }

    private var kioskModeSection: some View {
        Section(Localization.kioskMode) {
            NavigationLink(value: SettingsViewModel.Route.kioskMode) {
                LabeledContent(Localization.kioskMode) {
                    Text(viewModel.screenManager.stayAwake ? Localization.on : Localization.off)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section(Localization.about) {
            LabeledContent(Localization.version, value: Bundle.main.appVersion)
                .onTapGesture {
                    viewModel.versionTapped()
                }
            NavigationLink(Localization.acknowledgements) {
                AcknowledgementsView()
            }
            #if DEBUG
            NavigationLink {
                DebugPanelContentView()
            } label: {
                Label(Localization.debugPanel, systemImage: "ladybug")
            }
            #endif
        }
    }
}

private extension SettingsView {
    enum Localization {
        static let settings = String(localized: "Settings", comment: "Navigation title for the settings screen")
        static let close = String(localized: "Close", comment: "Button to dismiss the settings screen")
        static let done = String(localized: "Done", comment: "Button to dismiss the current screen")
        static let cancel = String(localized: "Cancel", comment: "Button to cancel the current action")

        // Server section
        static let server = String(localized: "Server", comment: "Settings section header for server connection details")
        static let url = String(localized: "URL", comment: "Label for the server URL in settings")
        static let version = String(localized: "Version", comment: "Label for the version in settings")
        static let openServer = String(localized: "Open Server", comment: "Button to open the Home Assistant web interface")

        // Logout
        static let logOut = String(localized: "Log Out", comment: "Destructive button to log out of the server")
        static let logOutQuestion = String(localized: "Log Out?", comment: "Alert title confirming logout")
        static let logOutMessage = String(localized: "This will remove all local data including your Home layout.", comment: "Alert message explaining logout will delete local data")
        static func logOutMessageWithHost(_ host: String) -> String {
            String(localized: "Log out of \(host)? This will remove all local data including your Home layout.", comment: "Alert message explaining logout will delete local data, with the server hostname")
        }

        // Kiosk Mode
        static let kioskMode = String(localized: "Kiosk Mode", comment: "Settings section header and navigation link for kiosk mode (stay awake, dimming)")
        static let on = String(localized: "On", comment: "Status label indicating a setting is enabled")
        static let off = String(localized: "Off", comment: "Status label indicating a setting is disabled")

        // About
        static let about = String(localized: "About", comment: "Settings section header for app information")
        static let acknowledgements = String(localized: "Acknowledgements", comment: "Navigation link to the open-source acknowledgements screen")
        static let debugPanel = String(localized: "Debug Panel", comment: "Button to open the debug panel from settings (debug builds only)")
    }
}

#if DEBUG
#Preview {
    ServiceLocator.configureForPreview()
    return SettingsView(viewModel: SettingsViewModel())
}
#endif
