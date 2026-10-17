import SwiftUI

public struct CardIcon: View {

    private enum Source {
        /// Material Design Icon name, resolved through the environment's provider.
        case mdi(name: String, fallback: String?)
        /// SF Symbol, for app chrome that isn't representing a Home Assistant entity.
        case systemImage(String)
    }

    private let source: Source?
    private let backgroundColor: Color
    private var onTap: (() -> Void)?

    /**
     Draws a Material Design Icon by name, e.g. `"mdi:lightbulb"`.
     - Parameter fallback: drawn when `icon` resolves to nothing, so no card shows a bare circle.
    */
    public init(icon: String?, fallback: String? = nil, backgroundColor: Color, onTap: (() -> Void)? = nil) {
        self.source = icon.map { .mdi(name: $0, fallback: fallback) }
        self.backgroundColor = backgroundColor
        self.onTap = onTap
    }

    /// Draws an SF Symbol. For chrome only — entity and area icons come from Home Assistant.
    public init(systemImage: String, backgroundColor: Color, onTap: (() -> Void)? = nil) {
        self.source = .systemImage(systemImage)
        self.backgroundColor = backgroundColor
        self.onTap = onTap
    }

    public var body: some View {
        icon
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

    /**
     Renders nothing but the circle when the name resolves to no glyph — an icon from a custom
     pack, or one this version of Material Design Icons doesn't contain.
    */
    @ViewBuilder
    private var icon: some View {
        switch source {
        case let .mdi(name, fallback):
            /**
             Inner size, not the circle's: an MDI glyph fills its viewBox edge to edge, so the
             full diameter would push artwork past the rim.
            */
            MDIIcon(name: name, fallback: fallback, size: Mortar.IconSize.s)
        case let .systemImage(name):
            Image(systemName: name)
                .imageScale(.large)
                .fontWeight(.bold)
                .contentTransition(.interpolate)
        case nil:
            EmptyView()
        }
    }
}

#Preview {
    VStack {
        CardIcon(systemImage: "arrow.up", backgroundColor: .blue)
    }
}
