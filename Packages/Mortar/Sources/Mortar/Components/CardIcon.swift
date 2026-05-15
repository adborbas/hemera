import SwiftUI

public struct CardIcon: View {
    public let iconName: String
    public let backgroundColor: Color
    public var onTap: (() -> Void)?

    public init(iconName: String, backgroundColor: Color, onTap: (() -> Void)? = nil) {
        self.iconName = iconName
        self.backgroundColor = backgroundColor
        self.onTap = onTap
    }

    public var body: some View {
        Image(systemName: iconName)
            .imageScale(.large)
            .fontWeight(.bold)
            .contentTransition(.interpolate)
            .foregroundStyle(Color.white)
            .frame(width: Mortar.IconSize.m, height: Mortar.IconSize.m)
            .background(
                Circle()
                    .fill(backgroundColor)
            )
            .onTapGesture {
                onTap?()
            }
            .allowsHitTesting(onTap != nil)
    }
}

#Preview {
    VStack {
        CardIcon(
            iconName: "arrow.up",
            backgroundColor: .blue
        )
    }
}
