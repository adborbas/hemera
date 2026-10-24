import SwiftUI

/// Which of the Mortar button styles to wear.
public enum MortarButtonKind {
    case primary
    case secondary
    case destructive

    /// Mirrors each style's foreground: a circular ProgressView reads `tint`, not foregroundStyle.
    var spinnerTint: Color {
        switch self {
        case .primary: .white
        case .secondary: .accentColor
        case .destructive: .red
        }
    }
}

/**
 A Mortar button that can be busy. Not a ButtonStyle: a style may read `isEnabled`, not set it,
 so it could never disable itself. Use the styles directly when a button is never busy.
*/
public struct MortarButton: View {

    private let title: String
    private let kind: MortarButtonKind
    private let width: MortarButtonWidth
    private let isLoading: Bool
    private let action: () -> Void

    /// `isLoading` is read, never written, so it is a value not a binding.
    public init(
        _ title: String,
        kind: MortarButtonKind = .primary,
        width: MortarButtonWidth = .intrinsic,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.kind = kind
        self.width = width
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        styled(
            Button(action: action) {
                // Hidden, not removed: keeps the button's width and VoiceOver's label.
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                    .overlay {
                        if isLoading {
                            ProgressView().tint(kind.spinnerTint)
                        }
                    }
            }
        )
        .disabled(isLoading)
    }

    @ViewBuilder
    private func styled(_ button: some View) -> some View {
        switch kind {
        case .primary: button.buttonStyle(.mortarPrimary(width: width))
        case .secondary: button.buttonStyle(.mortarSecondary(width: width))
        case .destructive: button.buttonStyle(.mortarDestructive(width: width))
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: Mortar.Spacing.l) {
        MortarButton("Connect", width: .fullWidth) {}
        MortarButton("Connect", width: .fullWidth, isLoading: true) {}
        MortarButton("Try Demo", kind: .secondary, isLoading: true) {}
        MortarButton("Log Out", kind: .destructive, isLoading: true) {}
    }
    .padding(Mortar.Spacing.xl)
}
#endif
