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

    init(authManager: any AuthManaging) {
        self.authManager = authManager
    }

    convenience init() {
        self.init(authManager: ServiceLocator.shared.authManager)
    }

    func startDiscovery() {
        discovery.startDiscovery()
    }

    func stopDiscovery() {
        discovery.stopDiscovery()
    }

    @discardableResult
    func connectManual() -> Bool {
        let trimmed = manualURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var urlString = trimmed
        if !urlString.contains("://") {
            urlString = "http://\(urlString)"
        }

        guard let components = URLComponents(string: urlString),
              let host = components.host, !host.isEmpty,
              let scheme = components.scheme, ["http", "https"].contains(scheme.lowercased()),
              let url = components.url else {
            errorMessage = Localization.invalidURLWithExample
            return false
        }

        connect(to: url)
        return true
    }

    func connect(to url: URL) {
        errorMessage = nil

        if url.scheme?.lowercased() == "http" {
            pendingHTTPURL = url
            showHTTPWarning = true
            return
        }

        startOAuth(url: url)
    }

    func confirmHTTPConnection() {
        if let url = pendingHTTPURL {
            pendingHTTPURL = nil
            startOAuth(url: url)
        }
    }

    func cancelHTTPWarning() {
        pendingHTTPURL = nil
    }

    func startOAuth(url: URL) {
        isConnecting = true
        errorMessage = nil

        do {
            authSession = try oauthManager.prepare(serverURL: url)
        } catch {
            errorMessage = Localization.invalidURL
            isConnecting = false
        }
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
        func logout() {}
    }
    #endif

    enum Localization {
        static let invalidURLWithExample = String(localized: "Please enter a valid URL (e.g. http://192.168.1.100:8123)", comment: "Validation error when the manually entered server URL is malformed")
        static let invalidURL = String(localized: "Invalid server URL.", comment: "Error message when OAuth preparation fails for the given server URL")
        static let authFailed = String(localized: "Authentication failed. Please try again.", comment: "Error message shown when OAuth login fails")
    }
}
