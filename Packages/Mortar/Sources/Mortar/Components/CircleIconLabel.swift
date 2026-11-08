import SwiftUI

/// An SF Symbol on a grey circle, the label of a control panel's round buttons and menus.
public struct CircleIconLabel: View {
    private let systemImage: String
    private let color: Color

    public init(systemImage: String, color: Color) {
        self.systemImage = systemImage
        self.color = color
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(color)
            .frame(width: Mortar.IconSize.m, height: Mortar.IconSize.m)
            .background {
                Circle().fill(PlatformColor.systemGray5)
            }
    }
}
