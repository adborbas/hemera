import SwiftUI

/// Which of the Mortar button styles to wear.
public enum MortarButtonKind {
    case primary
    case secondary
    case destructive

    /**
     Mirrors each style's `foregroundStyle`, because a circular `ProgressView` takes its
     colour from `tint` and ignores the foreground the style applies — left alone it draws
     the accent colour, which is near-invisible on the dimmed background of a busy button.
    */
    var spinnerTint: Color {
        switch self {
        case .primary: .white
        case .secondary: .accentColor
        case .destructive: .red
        }
    }
}

/**
 A Mortar button that can be busy.

 The styles cannot express this on their own: a `ButtonStyle` may read `isEnabled` but not set
 it, so showing a spinner and refusing taps had to be each caller's job, and they disagreed —
 some put a spinner beside the title, others swapped the whole control out.

 Reach for the styles directly when a button is never busy; this adds nothing else.
*/
public struct MortarButton: View {

    private let title: String
    private let kind: MortarButtonKind
    private let width: MortarButtonWidth
    private let isLoading: Bool
    private let action: () -> Void

    /// `isLoading` is read, never written, so it is a value rather than a binding.
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
                /**
                 The title stays in place and only turns invisible, so an intrinsic-width button
                 keeps its size and VoiceOver keeps its label while the spinner is up.
                */
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
