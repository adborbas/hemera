import SwiftUI

/// Draws a Material Design Icon by name, tinted by the current foreground style.
public struct MDIIcon: View {

    private let name: String
    private let fallback: String?
    private let size: CGFloat

    @Environment(\.mdiIconProvider) private var provider

    /**
     - Parameter fallback: drawn when `name` resolves to nothing — a custom pack, or a name this
       version of MDI lacks. `nil` draws nothing.
    */
    public init(name: String, fallback: String? = nil, size: CGFloat) {
        self.name = name
        self.fallback = fallback
        self.size = size
    }

    private var glyph: MDIGlyph? {
        provider.glyph(named: name) ?? fallback.flatMap { provider.glyph(named: $0) }
    }

    public var body: some View {
        if let glyph {
            Text(String(glyph.character))
                /**
                 Not `size:`, which scales with Dynamic Type and overflows the fixed-diameter
                 containers these sit in, like `CardIcon`'s circle.
                */
                .font(.custom(MDIIconFont.fontName, fixedSize: size))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}
