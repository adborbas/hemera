import SwiftUI

/// A compact dropdown pill that displays a title, icon, and current selection.
///
/// Tapping opens a native `Menu` to pick from the available options.
/// Designed to sit in rows alongside other `OptionPill`s for secondary settings.
public struct OptionPill<Option: Hashable>: View {
    public let icon: String
    public let title: String
    public let options: [Option]
    @Binding public var selection: Option?
    public let label: (Option) -> String
    public let onSelect: (Option) -> Void

    public init(
        icon: String,
        title: String,
        options: [Option],
        selection: Binding<Option?>,
        label: @escaping (Option) -> String,
        onSelect: @escaping (Option) -> Void
    ) {
        self.icon = icon
        self.title = title
        self.options = options
        self._selection = selection
        self.label = label
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                    onSelect(option)
                } label: {
                    if selection == option {
                        Label(label(option), systemImage: "checkmark")
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            HStack(spacing: Mortar.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(PlatformColor.systemGray)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(selection.map(label) ?? "—")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, Mortar.Spacing.s)
            .padding(.vertical, Mortar.Spacing.xs)
            .background(RoundedRectangle(cornerRadius: Mortar.Radii.s).fill(PlatformColor.systemGray5))
        }
        .tint(.primary)
    }
}

// MARK: - Convenience for String options

public extension OptionPill where Option == String {
    init(
        icon: String,
        title: String,
        options: [String],
        selection: Binding<String?>,
        onSelect: @escaping (String) -> Void
    ) {
        self.init(
            icon: icon,
            title: title,
            options: options,
            selection: selection,
            label: { $0.localizedCapitalized },
            onSelect: onSelect
        )
    }
}
