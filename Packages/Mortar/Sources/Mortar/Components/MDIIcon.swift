import SwiftUI

/**
 Draws a Material Design Icon by name, tinted by the current foreground style.

 Takes a name rather than a glyph so call sites never learn where icons come from.
*/
public struct MDIIcon: View {

    private let name: String
    private let fallback: String?
    private let size: CGFloat

    @Environment(\.mdiIconProvider) private var provider

    /**
     - Parameter fallback: drawn when `name` cannot be resolved at all — a custom icon pack, or a
       name this version of Material Design Icons does not contain. `nil` draws nothing instead.
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
                 `fixedSize` rather than `size`, which scales with Dynamic Type: these glyphs sit
                 inside fixed-diameter containers like `CardIcon`'s circle, so scaling the artwork
                 without scaling its container makes the glyph overflow the rim.
                */
                .font(.custom(MDIIconFont.fontName, fixedSize: size))
                /// Material Design Icon glyphs fill their em box, so a square frame of the same
                /// point size bounds the artwork and keeps layout deterministic.
                .frame(width: size, height: size)
                /// The label comes from the surrounding card, so the glyph itself is decorative.
                .accessibilityHidden(true)
        }
    }
}
