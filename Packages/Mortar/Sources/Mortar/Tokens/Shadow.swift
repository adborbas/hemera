import SwiftUI

extension Mortar {
    public enum Shadow {
        case subtle
        case soft
        case medium

        var radius: CGFloat {
            switch self {
            case .subtle: 2
            case .soft: 4
            case .medium: 6
            }
        }

        var y: CGFloat {
            switch self {
            case .subtle: 1
            case .soft: 2
            case .medium: 3
            }
        }

        var color: Color {
            switch self {
            case .subtle, .soft:
                Color("ShadowSubtle", bundle: .module)
            case .medium:
                Color("ShadowMedium", bundle: .module)
            }
        }
    }
}

public struct MortarShadowModifier: ViewModifier {
    let shadow: Mortar.Shadow

    public func body(content: Content) -> some View {
        content.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: 0,
            y: shadow.y
        )
    }
}

extension View {
    public func mortarShadow(_ shadow: Mortar.Shadow) -> some View {
        modifier(MortarShadowModifier(shadow: shadow))
    }
}
