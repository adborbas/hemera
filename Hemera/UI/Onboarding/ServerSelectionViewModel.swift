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

    /**
     Identifies the attempt in flight. Resolving takes seconds and nothing cancels it, so a
     result has to prove it is still wanted before it presents anything — otherwise backing
     out of manual entry still raises the warning, or the sign-in sheet, for the address you
     walked away from, on whatever screen you landed on.
    */
    private var attempt = 0

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
        let candidates = ServerAddress.candidates(manualURL)
        guard !candidates.isEmpty else {
            errorMessage = Localization.invalidURLWithExample
            return false
        }

        await connect(candidates: candidates)
        return errorMessage == nil
    }

    /// A discovered server names its own scheme, so there is nothing to resolve.
    func connect(to url: URL) async {
        await connect(candidates: [url])
    }

    /**
     Resolves the address, then warns only if the one that works is unencrypted.

     This reverses the earlier ordering, where the warning came first so that no cleartext
     request was sent without consent. Finding out whether http is even needed requires
     asking, and the probe carries no credentials — it only reveals that someone asked this
     host whether it runs Home Assistant. Warning on every scheme-less address instead told
     people nothing: it fired just as often when https would have worked.
    */
    private func connect(candidates: [URL]) async {
        // A second tap lands here before the first attempt has finished; the first one wins.
        guard !isConnecting else { return }

        attempt &+= 1
        let mine = attempt
        errorMessage = nil
        isConnecting = true

        do {
            let resolved = try await resolve(candidates)
            guard mine == attempt else { return }
            guard resolved.scheme?.lowercased() == "http" else {
                startSession(at: resolved)
                return
            }
            isConnecting = false
            pendingHTTPURL = resolved
            showHTTPWarning = true
        } catch {
            guard mine == attempt else { return }
            errorMessage = Self.message(for: error)
            isConnecting = false
        }
    }

    /// Leaving the screen abandons whatever it started, so a late result stays silent.
    func abandonConnection() {
        attempt &+= 1
        isConnecting = false
        pendingHTTPURL = nil
        showHTTPWarning = false
        errorMessage = nil
    }

    /// The first candidate that answers as Home Assistant wins.
    private func resolve(_ candidates: [URL]) async throws -> URL {
        var answered = false

        for (index, url) in candidates.enumerated() {
            let isLast = index == candidates.count - 1
            do {
                try await serverProbe.probe(url, timeout: isLast ? ServerProbe.confirmed : ServerProbe.speculative)
                return url
            } catch AuthError.notHomeAssistant {
                answered = true
            } catch {
                continue
            }
        }

        // "Something answered, but it wasn't Home Assistant" is the more actionable of the two.
        throw answered ? AuthError.notHomeAssistant : AuthError.serverUnreachable
    }

    func confirmHTTPConnection() async {
        guard let url = pendingHTTPURL else { return }
        pendingHTTPURL = nil
        isConnecting = true
        // `resolve` already proved this address serves Home Assistant.
        startSession(at: url)
    }

    func cancelHTTPWarning() {
        pendingHTTPURL = nil
    }

    private func startSession(at url: URL) {
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
