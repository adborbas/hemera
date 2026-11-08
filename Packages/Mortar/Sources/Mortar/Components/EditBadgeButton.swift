import SwiftUI

/// The small dark glyph circle on a tile in edit mode, inside a full-size tap target.
public struct EditBadgeButton: View {
    private let title: String
    private let systemImage: String
    private let action: () -> Void

    public init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
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
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}
