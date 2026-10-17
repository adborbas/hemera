import SwiftUI

/// A resolved Material Design Icon, ready to draw.
public struct MDIGlyph: Hashable, Sendable {
    let character: Character
}

/**
 Supplies Material Design Icon glyphs by name.

 The only thing views know about where icons come from. They ask for a name; whether it was resolved
 from the bundled font or something else entirely is the provider's business, so swapping the source
 never reaches a call site.
*/
public protocol MDIIconProviding: Sendable {

    /// The glyph for a Home Assistant icon name (`"mdi:garage"`), or `nil` if it cannot be resolved.
    func glyph(named name: String) -> MDIGlyph?
}

/// Resolves names against the Material Design Icons webfont vendored into Mortar.
public struct MDIFontIconProvider: MDIIconProviding {

    public init() {}

    public func glyph(named name: String) -> MDIGlyph? {
        guard let canonical = MDIIconName.normalised(name) else { return nil }
        return MDIIconFont.glyph(forCanonicalName: canonical)
    }
}

private struct MDIIconProviderKey: EnvironmentKey {
    static let defaultValue: any MDIIconProviding = MDIFontIconProvider()
}

public extension EnvironmentValues {
    var mdiIconProvider: any MDIIconProviding {
        get { self[MDIIconProviderKey.self] }
        set { self[MDIIconProviderKey.self] = newValue }
    }
}
