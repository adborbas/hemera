import SwiftUI

/// The small dark glyph circle on a tile in edit mode, inside a full-size tap target.
public struct EditBadgeButton: View {
    private let title: String
    private let systemImage: String
    private let hitDiameter: CGFloat
    private let action: () -> Void

    /// Under the minimum, `hitDiameter` makes the tap target a circle, so close badges don't overlap.
    public init(
        _ title: String,
        systemImage: String,
        hitDiameter: CGFloat = Mortar.TapTarget.minimum,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.hitDiameter = hitDiameter
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Mortar.IconSize.s, height: Mortar.IconSize.s)
                .background(
                    Circle()
                        .fill(.thinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
                .contentShape(hitDiameter < Mortar.TapTarget.minimum
                    ? AnyShape(Circle().inset(by: (Mortar.TapTarget.minimum - hitDiameter) / 2))
                    : AnyShape(Rectangle()))
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}
