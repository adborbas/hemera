import SwiftUI

// MARK: - Tile Size Environment

private struct MediumTileKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    public var isMediumTile: Bool {
        get { self[MediumTileKey.self] }
        set { self[MediumTileKey.self] = newValue }
    }
}

// MARK: - Entity Card

public struct EntityCard<Content: View, BackgroundOverlay: View>: View {

    private let tintColor: Color?
    private let isActive: Bool
    @ViewBuilder private let content: () -> Content
    @ViewBuilder private let backgroundOverlay: () -> BackgroundOverlay

    public init(
        tintColor: Color? = nil,
        isActive: Bool = false,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder backgroundOverlay: @escaping () -> BackgroundOverlay
    ) {
        self.tintColor = tintColor
        self.isActive = isActive
        self.content = content
        self.backgroundOverlay = backgroundOverlay
    }

    public var body: some View {
        content()
            .padding(.vertical, Mortar.Spacing.l)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .leading)
            .background { backgroundOverlay() }
            .cardBackground(tint: tintColor, isActive: isActive)
    }
}

extension EntityCard where BackgroundOverlay == EmptyView {
    public init(tintColor: Color? = nil, isActive: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.init(tintColor: tintColor, isActive: isActive, content: content) { EmptyView() }
    }
}

// MARK: - Adaptive Layout

extension EntityCard where Content == AdaptiveCardContent<AnyView, AnyView>, BackgroundOverlay == EmptyView {

    public init<Icon: View, Label: View>(
        tintColor: Color? = nil,
        isActive: Bool = false,
        @ViewBuilder icon: @escaping () -> Icon,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.init(tintColor: tintColor, isActive: isActive) {
            AdaptiveCardContent(
                icon: { AnyView(icon()) },
                label: { AnyView(label()) }
            )
        }
    }
}

extension EntityCard where Content == AdaptiveCardContent<AnyView, AnyView> {

    public init<Icon: View, Label: View>(
        tintColor: Color? = nil,
        isActive: Bool = false,
        @ViewBuilder icon: @escaping () -> Icon,
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder backgroundOverlay: @escaping () -> BackgroundOverlay
    ) {
        self.init(tintColor: tintColor, isActive: isActive, content: {
            AdaptiveCardContent(
                icon: { AnyView(icon()) },
                label: { AnyView(label()) }
            )
        }, backgroundOverlay: backgroundOverlay)
    }
}

public struct AdaptiveCardContent<Icon: View, Label: View>: View {
    @Environment(\.isMediumTile) private var isMedium

    @ViewBuilder public let icon: () -> Icon
    @ViewBuilder public let label: () -> Label

    public init(
        @ViewBuilder icon: @escaping () -> Icon,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.icon = icon
        self.label = label
    }

    public var body: some View {
        let layout = isMedium
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout())

        layout {
            icon()

            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: isMedium ? .infinity : nil, alignment: .bottom)
        }
    }
}

#if DEBUG
#Preview {
    VStack {
        EntityCard {
            VStack(alignment: .leading) {
                Text("Title")
                Text("Subtitle")
            }
        }

        EntityCard {
            VStack(alignment: .leading) {
                Text("Title")
                Text("Subtitle asd asdasdasdasdas das ")
            }
        }
    }
    .padding(Mortar.Spacing.m)
}
#endif
