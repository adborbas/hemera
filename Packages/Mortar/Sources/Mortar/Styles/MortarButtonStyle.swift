import SwiftUI

// MARK: - Width Mode

public enum MortarButtonWidth {
    case intrinsic
    case fixed(CGFloat)
    case fullWidth
}

// MARK: - Button Styles

public struct MortarPrimaryButtonStyle: ButtonStyle {
    let width: MortarButtonWidth

    public init(width: MortarButtonWidth = .intrinsic) {
        self.width = width
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.vertical, Mortar.Spacing.m)
            .padding(.horizontal, Mortar.Spacing.xl)
            .mortarButtonWidth(width)
            .foregroundStyle(.white)
            .background(.tint, in: RoundedRectangle(cornerRadius: Mortar.Radii.s, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

public struct MortarSecondaryButtonStyle: ButtonStyle {
    let width: MortarButtonWidth

    public init(width: MortarButtonWidth = .intrinsic) {
        self.width = width
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.vertical, Mortar.Spacing.m)
            .padding(.horizontal, Mortar.Spacing.xl)
            .mortarButtonWidth(width)
            .foregroundStyle(.tint)
            .background(PlatformColor.systemGray5, in: RoundedRectangle(cornerRadius: Mortar.Radii.s, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

public struct MortarDestructiveButtonStyle: ButtonStyle {
    let width: MortarButtonWidth

    public init(width: MortarButtonWidth = .intrinsic) {
        self.width = width
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.vertical, Mortar.Spacing.m)
            .padding(.horizontal, Mortar.Spacing.xl)
            .mortarButtonWidth(width)
            .foregroundStyle(.red)
            .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: Mortar.Radii.s, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Width Modifier

private extension View {
    @ViewBuilder
    func mortarButtonWidth(_ width: MortarButtonWidth) -> some View {
        switch width {
        case .intrinsic:
            self
        case .fixed(let value):
            self.frame(width: value)
        case .fullWidth:
            self.frame(maxWidth: .infinity)
        }
    }
}

// MARK: - ButtonStyle extensions

extension ButtonStyle where Self == MortarPrimaryButtonStyle {
    public static func mortarPrimary(width: MortarButtonWidth = .intrinsic) -> MortarPrimaryButtonStyle {
        MortarPrimaryButtonStyle(width: width)
    }
}

extension ButtonStyle where Self == MortarSecondaryButtonStyle {
    public static func mortarSecondary(width: MortarButtonWidth = .intrinsic) -> MortarSecondaryButtonStyle {
        MortarSecondaryButtonStyle(width: width)
    }
}

extension ButtonStyle where Self == MortarDestructiveButtonStyle {
    public static func mortarDestructive(width: MortarButtonWidth = .intrinsic) -> MortarDestructiveButtonStyle {
        MortarDestructiveButtonStyle(width: width)
    }
}
