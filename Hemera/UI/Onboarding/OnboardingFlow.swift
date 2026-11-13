import SwiftUI

struct OnboardingFlow: View {

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { path.append(OnboardingDestination.serverSelection) }
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
