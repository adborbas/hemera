import SwiftUI

@Observable
@MainActor
final class ServerURLViewModel {

    // MARK: - Properties

    var text: String
    private(set) var isBusy = false
    private(set) var errorMessage: String?

    private(set) var mode: ServerAddressMode
    private let urlChanger: any ServerURLChanging

    // MARK: - Init

    init(mode: ServerAddressMode, urlChanger: any ServerURLChanging) {
        self.mode = mode
        self.urlChanger = urlChanger
        self.text = mode.initialText
    }

    convenience init() {
        let sl = ServiceLocator.shared
        let current = sl.authManager.credentials?.serverURL
        self.init(
            mode: current.map { .edit(current: $0) } ?? .initial,
            urlChanger: sl.sessionManager
        )
    }

    // MARK: - Public Methods

    var canSubmit: Bool {
        !isBusy && mode.allowsSubmitting(text)
    }

    func save() async -> ServerAddressSubmitResult {
        guard let candidate = ServerAddress.normalised(text) else {
            errorMessage = Localization.invalidURL
            return .failed
        }
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try await urlChanger.changeServerURL(to: candidate)
            return .succeeded
        } catch AuthError.differentServer {
            errorMessage = Localization.differentServer
        } catch AuthError.serverUnreachable {
            errorMessage = Localization.unreachable
        } catch {
            errorMessage = Localization.genericFailure
        }
        return .failed
    }
}

// MARK: - ServerAddressHandling

extension ServerURLViewModel: ServerAddressHandling {
    func submit() async -> ServerAddressSubmitResult {
        await save()
    }
}

// MARK: - Localization

private extension ServerURLViewModel {
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
