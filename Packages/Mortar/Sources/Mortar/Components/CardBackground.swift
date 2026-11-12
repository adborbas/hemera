import SwiftUI

/// How cards draw their background, chosen through `\.cardSurface`.
public enum CardSurface: Sendable {
    /// A translucent fill: grey when off, a light tint wash when on.
    case wash
    /// Frosted material when off, a strong tint on an opaque base when on; for busy backgrounds.
    case frosted
}

extension EnvironmentValues {
    /// The surface every card below draws on.
    @Entry public var cardSurface: CardSurface = .wash
}

private struct CardBackgroundModifier<BackgroundOverlay: View>: ViewModifier {
    let tint: Color?
    let isActive: Bool
    let isWorking: Bool
    @ViewBuilder let backgroundOverlay: () -> BackgroundOverlay
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardSurface) private var surface

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if surface == .frosted {
                        frostedBase
                    }
                    RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous)
                        .fill(fillColor)
                    backgroundOverlay()
                }
            }
            .overlay {
                ActivityBorder(color: tint ?? PlatformColor.systemGray,
                               isActive: isWorking && !reduceMotion,
                               cornerRadius: Mortar.Radii.l)
            }
    }

    private var isTintedOn: Bool { tint != nil && isActive }

    private var fillColor: Color {
        switch surface {
        case .wash:
            guard let tint else {
                return PlatformColor.secondarySystemBackground
            }
            return isActive ? Mortar.cardTintWash(tint, in: colorScheme) : PlatformColor.secondarySystemBackground
        case .frosted:
            return isActive ? tint?.opacity(0.55) ?? .clear : .clear
        }
    }

    @ViewBuilder
    private var frostedBase: some View {
        let shape = RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous)
        if isTintedOn {
            shape.fill(PlatformColor.secondarySystemBackground)
        } else {
            shape.fill(.regularMaterial)
        }
    }
}

extension Mortar {
    /// The wash an active, tinted card shows instead of its grey background.
    static func cardTintWash(_ tint: Color, in colorScheme: ColorScheme) -> Color {
        tint.opacity(colorScheme == .dark ? 0.28 : 0.15)
    }
}

extension View {
    /// Applies the standard card background.
    ///
    /// When `tint` is provided, the background adapts by color scheme:
    /// - **Light mode**: active cards get a tinted wash (15% opacity).
    /// - **Dark mode**: active cards get a stronger tinted wash (28% opacity).
    /// - Inactive cards use `secondarySystemBackground` regardless of mode.
    ///
    /// When `tint` is `nil`, uses `secondarySystemBackground` regardless of mode.
    /// `isWorking` traces the card's border with a travelling segment while a task is in flight.
    ///
    /// `backgroundOverlay` draws on top of the fill, within the card's rounded shape.
    public func cardBackground<BackgroundOverlay: View>(
        tint: Color? = nil,
        isActive: Bool = false,
        isWorking: Bool = false,
        @ViewBuilder backgroundOverlay: @escaping () -> BackgroundOverlay = { EmptyView() }
    ) -> some View {
        modifier(CardBackgroundModifier(tint: tint,
                                        isActive: isActive,
                                        isWorking: isWorking,
                                        backgroundOverlay: backgroundOverlay))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let surfaces: [CardSurface] = [.wash, .frosted]

    HStack(spacing: Mortar.Spacing.m) {
        ForEach(surfaces, id: \.self) { surface in
            VStack(spacing: Mortar.Spacing.m) {
                Text("On").frame(width: 140, height: 80).cardBackground(tint: .yellow, isActive: true)
                Text("Off").frame(width: 140, height: 80).cardBackground(tint: .yellow)
                Text("Untinted").frame(width: 140, height: 80).cardBackground()
            }
            .environment(\.cardSurface, surface)
        }
    }
    .padding(Mortar.Spacing.xl)
    .background {
        LinearGradient(colors: [.purple, .orange, .teal, .pink],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: "sparkles").resizable().scaledToFit().foregroundStyle(.white)
            }
    }
}
#endif
