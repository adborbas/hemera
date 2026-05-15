import SwiftUI

struct OnboardingFlow: View {

    var sessionExpiredMessage: String?
    var onTryDemo: (() -> Void)?

    @Environment(AppRouter.self) private var router
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(sessionExpiredMessage: sessionExpiredMessage, onTryDemo: onTryDemo)
                .navigationDestination(for: OnboardingDestination.self) { destination in
                    switch destination {
                    case .serverSelection:
                        ServerSelectionView(viewModel: ServerSelectionViewModel())
                    }
                }
        }
        .onAppear {
            if router.destination == .connectToServer {
                path.append(OnboardingDestination.serverSelection)
            }
        }
    }
}

enum OnboardingDestination: Hashable {
    case serverSelection
}
