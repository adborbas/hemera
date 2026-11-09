import SwiftUI

public struct PillPicker<Option: Hashable>: View {
    public let options: [Option]
    @Binding public var selection: Option
    private let content: Content
    private let identifier: ((Option) -> String)?

    @Namespace private var selectionSpace

    private enum Content {
        case icon((Option) -> String)
        case title((Option) -> String, accessibilityLabel: (Option) -> String)
    }

    public init(options: [Option], selection: Binding<Option>, icon: @escaping (Option) -> String) {
        self.options = options
        self._selection = selection
        self.content = .icon(icon)
        self.identifier = nil
    }

    /// A compact picker of short titles, read out by their spoken labels.
    public init(
        options: [Option],
        selection: Binding<Option>,
        title: @escaping (Option) -> String,
        accessibilityLabel: @escaping (Option) -> String,
        accessibilityIdentifier: ((Option) -> String)? = nil
    ) {
        self.options = options
        self._selection = selection
        self.content = .title(title, accessibilityLabel: accessibilityLabel)
        self.identifier = accessibilityIdentifier
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = option == selection
                cell(option, isSelected: isSelected)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(.thickMaterial)
                                .mortarShadow(.soft)
                                .matchedGeometryEffect(id: 0, in: selectionSpace)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(Mortar.Motion.springBouncy) {
                            selection = option
                        }
                    }
                    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                    .accessibilityIdentifier(identifier?(option) ?? "")
            }
        }
        .padding(isCompact ? Mortar.Spacing.xxs : Mortar.Spacing.xs)
        .background(
            Capsule().fill(PlatformColor.systemGray5)
        )
    }

    private var isCompact: Bool {
        if case .title = content { true } else { false }
    }

    @ViewBuilder
    private func cell(_ option: Option, isSelected: Bool) -> some View {
        switch content {
        case .icon(let icon):
            Image(systemName: icon(option))
                .font(.title3)
                .foregroundStyle(PlatformColor.systemGray)
                .frame(width: Mortar.IconSize.m, height: Mortar.IconSize.m)
        case .title(let title, let accessibilityLabel):
            Text(title(option))
                .font(.footnote.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, Mortar.Spacing.m)
                .padding(.vertical, Mortar.Spacing.xs)
                .accessibilityLabel(accessibilityLabel(option))
        }
    }
}
