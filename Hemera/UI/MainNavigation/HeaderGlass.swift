import SwiftUI
import Mortar

/// The header's glass plate with rounded bottom corners.
struct HeaderBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.bottom, Mortar.Spacing.s)
            .background {
                let shape = UnevenRoundedRectangle(
                    bottomLeadingRadius: Mortar.Radii.l,
                    bottomTrailingRadius: Mortar.Radii.l
                )
                Group {
                    if #available(iOS 26, *) {
                        Color.clear.glassEffect(.regular, in: shape)
                    } else {
                        shape.fill(.bar)
                    }
                }
                // Reaches past the top of the screen, so only the bottom edge shows the glass's rim.
                .padding(.top, -Mortar.Spacing.xxl * 4)
                .ignoresSafeArea(edges: .top)
            }
    }
}

/// Glass behind floating header buttons; inactive it draws nothing, and switching animates it.
struct GlassCapsule: ViewModifier {
    var isActive = true

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(isActive ? .regular.interactive() : .identity, in: .capsule)
        } else {
            content.background(.regularMaterial.opacity(isActive ? 1 : 0), in: .capsule)
        }
    }
}

/// Material vanishes on the light glass plate, so light mode uses a grey fill instead.
enum PillFill {
    static func unselected(_ scheme: ColorScheme) -> AnyShapeStyle {
        scheme == .light ? AnyShapeStyle(Color(.secondarySystemFill)) : AnyShapeStyle(.regularMaterial)
    }
}
