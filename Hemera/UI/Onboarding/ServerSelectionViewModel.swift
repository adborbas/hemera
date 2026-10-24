import Foundation

@Observable
@MainActor
final class ServerSelectionViewModel {

    enum DiscoveryState {
        case scanning
        case found
        case empty
    }

    var discovery = ServerDiscovery()
    var manualURL = ""
    var isConnecting = false
    var errorMessage: String?
    var showHTTPWarning = false
    var pendingHTTPURL: URL?
    var authSession: OAuthFlowManager.AuthSession?

    var discoveryState: DiscoveryState {
        if !discovery.servers.isEmpty {
            return .found
        } else if discovery.isScanning {
            return .scanning
        } else {
            return .empty
        }
    }

    private let oauthManager = OAuthFlowManager()
    private let authManager: any AuthManaging
    private let serverProbe: any ServerProbing

    init(authManager: any AuthManaging, serverProbe: any ServerProbing = ServerProbe()) {
        self.authManager = authManager
        self.serverProbe = serverProbe
    }

    convenience init() {
        self.init(authManager: ServiceLocator.shared.authManager)
    }

    func prepareManualEntry() {
        errorMessage = nil
    }

    func startDiscovery() {
        discovery.startDiscovery()
    }

    func stopDiscovery() {
        discovery.stopDiscovery()
    }

    var canConnect: Bool {
        !isConnecting && ServerAddressMode.initial.allowsSubmitting(manualURL)
    }

    @discardableResult
    func connectManual() async -> Bool {
        guard let url = ServerAddress.normalised(manualURL) else {
            errorMessage = Localization.invalidURLWithExample
            return false
        }

        await connect(to: url)
        return errorMessage == nil
    }

    func connect(to url: URL) async {
        errorMessage = nil

        /**
         The warning comes before the probe deliberately: probing already sends the cleartext
         request the user is being asked to consent to.
        */
        if url.scheme?.lowercased() == "http" {
            pendingHTTPURL = url
            showHTTPWarning = true
            return
        }

        await startOAuth(url: url)
    }

    func confirmHTTPConnection() async {
        if let url = pendingHTTPURL {
            pendingHTTPURL = nil
            await startOAuth(url: url)
        }
    }

    func cancelHTTPWarning() {
        pendingHTTPURL = nil
    }

    func startOAuth(url: URL) async {
        isConnecting = true
        errorMessage = nil

        do {
            try await serverProbe.probe(url)
        } catch {
            errorMessage = Self.message(for: error)
            isConnecting = false
            return
        }

        do {
            authSession = try oauthManager.prepare(serverURL: url)
        } catch {
            errorMessage = Localization.invalidURL
            isConnecting = false
        }
    }

    /// The sign-in page itself failed to load, so the address passed the probe but can't be used.
    func authSessionFailed() {
        authSession = nil
        isConnecting = false
        errorMessage = Localization.unreachable
    }

    func handleOAuthCallback(url: URL, session: OAuthFlowManager.AuthSession) async {
        do {
            let creds = try await oauthManager.handleCallback(url: url, session: session)
            authManager.didAuthenticate(with: creds)
        } catch {
            errorMessage = Localization.authFailed
        }
        isConnecting = false
    }

    func cancelAuth() {
        authSession = nil
        isConnecting = false
    }

    #if DEBUG
    static var previewWithServers: ServerSelectionViewModel {
        let vm = ServerSelectionViewModel(authManager: PreviewAuthManager())
        vm.discovery = .preview(servers: [
            DiscoveredServer(name: "Home", host: "192.168.68.54", port: 8123),
            DiscoveredServer(name: "Office", host: "192.168.68.120", port: 8123),
        ])
        return vm
    }

    static var previewScanning: ServerSelectionViewModel {
        let vm = ServerSelectionViewModel(authManager: PreviewAuthManager())
        vm.discovery = .preview(servers: [], isScanning: true)
        return vm
    }

    static var previewEmpty: ServerSelectionViewModel {
        ServerSelectionViewModel(authManager: PreviewAuthManager())
    }

    private final class PreviewAuthManager: AuthManaging {
        var state: AuthState = .unauthenticated
        var credentials: ServerCredentials?
        func addOnChangeHandler(_ handler: @escaping (AuthState, AuthChangeReason) -> Void) {}
        func didAuthenticate(with creds: ServerCredentials) {}
        func validAccessToken() async throws -> String { "mock" }
        func updateServerURL(to url: URL) async throws {}
        func logout() {}
    }
    #endif

    /// Separated so the user knows whether to fix the address or fix the network.
    static func message(for error: Error) -> String {
        switch error {
        case AuthError.notHomeAssistant: Localization.notHomeAssistant
        default: Localization.unreachable
        }
    }

    enum Localization {
        static let invalidURLWithExample = String(localized: "Please enter a valid URL (e.g. http://192.168.1.100:8123)", comment: "Validation error when the manually entered server URL is malformed")
        static let invalidURL = String(localized: "Invalid server URL.", comment: "Error message when OAuth preparation fails for the given server URL")
        static let authFailed = String(localized: "Authentication failed. Please try again.", comment: "Error message shown when OAuth login fails")
        static let unreachable = String(
            localized: "Couldn't reach this address. Check it's correct and that you're connected to a network that can reach it.",
            comment: "Error shown when the entered Home Assistant address cannot be reached at all"
        )
        static let notHomeAssistant = String(
            localized: "This address answered, but it isn't a Home Assistant. Check the address and the port.",
            comment: "Error shown when the entered address is reachable but serves something other than Home Assistant"
        )
    }
}

// MARK: - ServerAddressHandling

/// Forwards to this view model's own vocabulary — it does far more than address entry.
extension ServerSelectionViewModel: ServerAddressHandling {
    var text: String {
        get { manualURL }
        set { manualURL = newValue }
    }

    var mode: ServerAddressMode { .initial }
    var isBusy: Bool { isConnecting }
    var canSubmit: Bool { canConnect }

    func submit() async -> Bool {
        await connectManual()
    }
}
