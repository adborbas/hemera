import SwiftUI

@Observable
@MainActor
final class ServerURLViewModel {

    // MARK: - Properties

    var urlText: String
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var didSave = false

    private let currentURL: URL?
    private let urlChanger: any ServerURLChanging

    // MARK: - Init

    init(currentURL: URL?, urlChanger: any ServerURLChanging) {
        self.currentURL = currentURL
        self.urlChanger = urlChanger
        self.urlText = currentURL?.absoluteString ?? ""
    }

    convenience init() {
        let sl = ServiceLocator.shared
        self.init(
            currentURL: sl.authManager.credentials?.serverURL,
            urlChanger: sl.sessionManager
        )
    }

    // MARK: - Public Methods

    var canSave: Bool {
        guard !isSaving, let candidate = normalisedURL else { return false }
        // Compare like with like: the stored URL may carry a trailing slash the typed one won't.
        return candidate != normalisedCurrentURL
    }

    func save() async {
        guard let candidate = normalisedURL else {
            errorMessage = Localization.invalidURL
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try await urlChanger.changeServerURL(to: candidate)
            didSave = true
        } catch AuthError.differentServer {
            errorMessage = Localization.differentServer
        } catch AuthError.serverUnreachable {
            errorMessage = Localization.unreachable
        } catch {
            errorMessage = Localization.genericFailure
        }
    }
}

// MARK: - Private

private extension ServerURLViewModel {
    /**
     Mirrors the normalisation in `ServerSelectionViewModel.connectManual()` — bare hosts
     default to `http`, since a LAN or VPN address usually has no scheme typed.
    */
    var normalisedURL: URL? {
        Self.normalised(urlText)
    }

    var normalisedCurrentURL: URL? {
        currentURL.flatMap { Self.normalised($0.absoluteString) }
    }

    static func normalised(_ input: String) -> URL? {
        let trimmed = input
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }

        let urlString = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let components = URLComponents(string: urlString),
              let host = components.host, !host.isEmpty,
              let scheme = components.scheme, ["http", "https"].contains(scheme.lowercased()),
              let url = components.url else {
            return nil
        }
        return url
    }

    enum Localization {
        static let invalidURL = String(
            localized: "Please enter a valid URL (e.g. http://192.168.1.100:8123)",
            comment: "Validation error when the entered server address is malformed"
        )
        static let differentServer = String(
            localized: "This address reaches a different Home Assistant. Hemera kept your current address so you stay signed in.",
            comment: "Error shown when the new server address serves a different Home Assistant instance than the one the user is signed in to"
        )
        static let unreachable = String(
            localized: "Couldn't reach this address. Check it's correct and that you're connected to a network that can reach it.",
            comment: "Error shown when the new server address cannot be reached"
        )
        static let genericFailure = String(
            localized: "Couldn't change the address. Please try again.",
            comment: "Generic error shown when changing the server address fails"
        )
    }
}
