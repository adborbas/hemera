import Foundation

/// What onboarding needs from the server connection beyond its address field.
@MainActor
protocol OnboardingServerConnecting: ServerAddressHandling {
    func prepareManualEntry()
    func abandonConnection()
    func cancelAuth()
}

extension ServerSelectionViewModel: OnboardingServerConnecting {}

/// Owns onboarding's flow: which page shows, the progress, Back and the bottom button.
@Observable
@MainActor
final class OnboardingCoordinator {

    /// In the order the user meets them, so comparing two pages tells forward from back.
    enum Page: Int, Comparable {
        case server
        case manualAddress
        case login

        static func < (lhs: Page, rhs: Page) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Out of `stepCount`. The manual address is a half step, so the bar only moves forward.
        var progress: Double {
            switch self {
            case .server: 1
            case .manualAddress: 1.5
            case .login: 2
            }
        }
    }

    struct BottomButton: Equatable {
        let title: String
        let isEnabled: Bool
        let isLoading: Bool
    }

    static let stepCount = 2

    // MARK: - Properties

    private(set) var page: Page = .server
    /// The page behind the login sheet while it is open, otherwise `page`.
    private(set) var contentPage: Page = .server
    private(set) var isForward = true

    private let connection: any OnboardingServerConnecting

    // MARK: - Init

    init(connection: any OnboardingServerConnecting) {
        self.connection = connection
    }

    // MARK: - Public Methods

    var progress: Double { page.progress }

    var canGoBack: Bool { contentPage != .server }

    /// `nil` hides the button.
    var bottomButton: BottomButton? {
        guard contentPage == .manualAddress else { return nil }
        return BottomButton(
            title: connection.mode.actionTitle,
            isEnabled: connection.canSubmit,
            isLoading: connection.isBusy
        )
    }

    func bottomButtonTapped() async {
        guard bottomButton?.isEnabled == true else { return }
        _ = await connection.submit()
    }

    func enterAddressManually() {
        connection.prepareManualEntry()
        show(.manualAddress)
    }

    func loginOpened() {
        guard page != .login else { return }
        isForward = true
        page = .login
    }

    func loginCancelled() {
        guard page == .login else { return }
        connection.cancelAuth()
        isForward = false
        page = contentPage
    }

    func back() {
        switch page {
        case .server:
            break
        case .manualAddress:
            connection.abandonConnection()
            show(.server)
        case .login:
            loginCancelled()
        }
    }
}

// MARK: - Private Methods

private extension OnboardingCoordinator {
    func show(_ next: Page) {
        isForward = next > page
        page = next
        contentPage = next
    }
}
