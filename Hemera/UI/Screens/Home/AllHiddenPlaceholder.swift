import SwiftUI
import Mortar

/// Shown in an area whose every entity is hidden, giving the user a way back
/// into Show/Hide mode to reveal them (the grid is otherwise empty and offers
/// no tile to long-press).
struct AllHiddenPlaceholder: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: Mortar.Spacing.m) {
            Image(systemName: "eye.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(Localization.title)
                .font(.headline)
            Text(Localization.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(Localization.showHidden, action: action)
                .buttonStyle(.borderedProminent)
                .padding(.top, Mortar.Spacing.xs)
        }
    }
}

// MARK: - Localization

private extension AllHiddenPlaceholder {
    enum Localization {
        static let title = String(localized: "All Items Hidden", comment: "Title of the placeholder shown when every entity in an area is hidden")
        static let subtitle = String(localized: "Every item in this area is hidden. Reveal items to show them here again.", comment: "Explanation under the all-items-hidden placeholder")
        static let showHidden = String(localized: "Show Hidden Items", comment: "Button that enters show/hide mode so hidden entities can be revealed")
    }
}
