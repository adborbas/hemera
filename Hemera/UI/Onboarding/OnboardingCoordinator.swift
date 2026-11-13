import Foundation

/// What onboarding needs from the server connection beyond its address field.
@MainActor
protocol OnboardingServerConnecting: ServerAddressHandling {
    func prepareManualEntry()
    func abandonConnection()
    func cancelAuth()
}

extension ServerSelectionViewModel: OnboardingServerConnecting {}

/// How onboarding learns the first sync finished, and hands the root to the main app.
@MainActor
protocol OnboardingRouting: AnyObject {
    var isSessionReady: Bool { get }
    func navigate(to destination: AppRouter.Destination)
}

extension AppRouter: OnboardingRouting {}

/// Owns onboarding's flow: which page shows, the progress, Back and the bottom button.
@Observable
@MainActor
final class OnboardingCoordinator {

    /// In the order the user meets them, so comparing two pages tells forward from back.
    enum Page: Int, Comparable {
        case server
        case manualAddress
        case login
        case home

        static func < (lhs: Page, rhs: Page) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Out of `stepCount`. The manual address is a half step, so the bar only moves forward.
        var progress: Double {
            switch self {
            case .server: 1
            case .manualAddress: 1.5
            case .login: 2
            case .home: 3
            }
        }
    }

    struct BottomButton: Equatable {
        let title: String
        let isEnabled: Bool
        let isLoading: Bool
    }

    static let stepCount = 3

    // MARK: - Properties

    private(set) var page: Page = .server
    /// The page behind the login sheet while it is open, otherwise `page`.
    private(set) var contentPage: Page = .server
    private(set) var isForward = true
    /// The Home step's editor, set by the login that opens the step.
    private(set) var home: CuratedHomeViewModel?
    private(set) var isConfirmingLogOut = false

    private let connection: any OnboardingServerConnecting
    private let authManager: any AuthManaging
    private let router: any OnboardingRouting

    // MARK: - Init

    init(connection: any OnboardingServerConnecting, authManager: any AuthManaging, router: any OnboardingRouting) {
        self.connection = connection
        self.authManager = authManager
        self.router = router
    }

    // MARK: - Public Methods

    var progress: Double { page.progress }

    var canGoBack: Bool { contentPage != .server }

    var isHomeLoaded: Bool { router.isSessionReady }

    var serverHost: String { authManager.credentials?.serverURL.host() ?? "" }

    /// `nil` hides the button.
    var bottomButton: BottomButton? {
        switch contentPage {
        case .manualAddress:
            BottomButton(title: connection.mode.actionTitle, isEnabled: connection.canSubmit, isLoading: connection.isBusy)
        case .home:
            BottomButton(title: Localization.finish, isEnabled: isHomeLoaded, isLoading: false)
        case .server, .login:
            nil
        }
    }

    func bottomButtonTapped() async {
        guard bottomButton?.isEnabled == true else { return }
        if contentPage == .home {
            home?.exitEditMode(commit: true)
            router.navigate(to: .authenticated)
        } else {
            _ = await connection.submit()
        }
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

    func loggedIn(home: CuratedHomeViewModel) {
        self.home = home
        show(.home)
    }

    /// Logging out wipes the Home, so nothing is saved.
    func logOut() {
        isConfirmingLogOut = false
        home = nil
        connection.cancelAuth()
        connection.abandonConnection()
        authManager.logout()
        show(.server)
    }

    func cancelLogOut() {
        isConfirmingLogOut = false
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
        case .home:
            isConfirmingLogOut = true
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

// MARK: - Localization

private extension OnboardingCoordinator {
    enum Localization {
        static let finish = String(localized: "Finish", comment: "Button ending onboarding and opening the app")
    }
}
