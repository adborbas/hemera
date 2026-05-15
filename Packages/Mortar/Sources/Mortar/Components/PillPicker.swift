import SwiftUI

public struct PillPicker<Option: Hashable>: View {
    public let options: [Option]
    @Binding public var selection: Option
    public let icon: (Option) -> String

    public init(options: [Option], selection: Binding<Option>, icon: @escaping (Option) -> String) {
        self.options = options
        self._selection = selection
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Image(systemName: icon(option))
                    .font(.title3)
                    .foregroundStyle(PlatformColor.systemGray)
                    .frame(width: Mortar.IconSize.m, height: Mortar.IconSize.m)
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(Mortar.Motion.springBouncy) {
                            selection = option
                        }
                    }
            }
        }
        .padding(Mortar.Spacing.xs)
        .background {
            GeometryReader { geo in
                let count = CGFloat(options.count)
                let buttonWidth = geo.size.width / count
                let selectedIndex = CGFloat(options.firstIndex(of: selection) ?? 0)
                Capsule()
                    .fill(.thickMaterial)
                    .mortarShadow(.soft)
                    .frame(width: Mortar.IconSize.m, height: Mortar.IconSize.m)
                    .position(
                        x: selectedIndex * buttonWidth + buttonWidth / 2,
                        y: geo.size.height / 2
                    )
            }
        }
        .background(
            Capsule().fill(PlatformColor.systemGray5)
        )
    }
}
