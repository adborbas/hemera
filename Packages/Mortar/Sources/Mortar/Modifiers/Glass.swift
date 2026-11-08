import SwiftUI

extension View {
    /// Glass capsule behind floating buttons; inactive it draws nothing, and switching animates it.
    @ViewBuilder
    public func mortarGlass(isActive: Bool = true) -> some View {
        if #available(iOS 26, macOS 26, *) {
            glassEffect(isActive ? .regular.interactive() : .identity, in: .capsule)
        } else {
            background(.regularMaterial.opacity(isActive ? 1 : 0), in: .capsule)
        }
    }

    /// A header's glass plate with rounded bottom corners, reaching up past the top of the screen.
    public func mortarHeaderGlass(isPlateVisible: Bool = true) -> some View {
        modifier(HeaderGlass(isPlateVisible: isPlateVisible))
    }
}

extension ShapeStyle where Self == AnyShapeStyle {
    /// An unselected chip's fill; material vanishes on the light glass plate, so light mode is grey.
    public static func chipFill(_ scheme: ColorScheme) -> AnyShapeStyle {
        scheme == .light ? AnyShapeStyle(PlatformColor.secondarySystemFill) : AnyShapeStyle(.regularMaterial)
    }
}

private struct HeaderGlass: ViewModifier {
    let isPlateVisible: Bool

    func body(content: Content) -> some View {
        content
            .padding(.bottom, Mortar.Spacing.s)
            .background {
                let shape = UnevenRoundedRectangle(
                    bottomLeadingRadius: Mortar.Radii.l,
                    bottomTrailingRadius: Mortar.Radii.l
                )
                Group {
                    if #available(iOS 26, macOS 26, *) {
                        Color.clear.glassEffect(isPlateVisible ? .regular : .identity, in: shape)
                    } else {
                        shape.fill(.bar).opacity(isPlateVisible ? 1 : 0)
                    }
                }
                .animation(.easeInOut(duration: Mortar.Motion.normal), value: isPlateVisible)
                // Reaches past the top of the screen, so only the bottom edge shows the glass's rim.
                .padding(.top, -Mortar.Spacing.xxl * 4)
                .ignoresSafeArea(edges: .top)
            }
    }
}
