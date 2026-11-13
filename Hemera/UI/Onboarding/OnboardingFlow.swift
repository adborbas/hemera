import SwiftUI

struct OnboardingFlow: View {

    var onTryDemo: (() -> Void)?

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(onTryDemo: onTryDemo)
                .navigationDestination(for: OnboardingDestination.self) { destination in
                    switch destination {
                    case .serverSelection:
                        ServerSelectionView(viewModel: ServerSelectionViewModel())
                    }
                }
        }
    }
}

enum OnboardingDestination: Hashable {
    case serverSelection
}
