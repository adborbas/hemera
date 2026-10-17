import CoreText
import Foundation

/**
 The vendored Material Design Icons webfont.

 The full set ships in the binary — roughly 1.25 MB for 7,447 glyphs — so an icon never depends on
 the network, a cache, or which icons someone guessed would be common. Run
 `scripts/update-mdi-icons.sh` to refresh it, pinned to the version Home Assistant's frontend ships.
*/
enum MDIIconFont {

    /// Must match the font's PostScript name; `update-mdi-icons.sh` fails the build if it drifts.
    static let fontName = "MaterialDesignIcons"

    /// Package resources are invisible to `UIAppFonts`, so the font is registered at first use.
    private static let isRegistered: Bool = {
        guard let url = Bundle.module.url(forResource: "materialdesignicons-webfont", withExtension: "ttf") else {
            assertionFailure("MDI webfont missing from Mortar resources — run scripts/update-mdi-icons.sh")
            return false
        }
        var error: Unmanaged<CFError>?
        let didRegister = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !didRegister, let error {
            // Already registered is benign; anything else means nothing will draw.
            let code = CFErrorGetCode(error.takeUnretainedValue())
            return code == CTFontManagerError.alreadyRegistered.rawValue
        }
        return didRegister
    }()

    private static let codepoints: [String: String] = {
        guard let url = Bundle.module.url(forResource: "MDICodepoints", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let table = root["codepoints"] as? [String: String] else {
            assertionFailure("MDICodepoints.json missing or malformed — run scripts/update-mdi-icons.sh")
            return [:]
        }
        return table
    }()

    /// The glyph for a canonical MDI name, or `nil` if this version of the font has no such icon.
    static func glyph(forCanonicalName name: String) -> MDIGlyph? {
        guard isRegistered,
              let hex = codepoints[name],
              let value = UInt32(hex, radix: 16),
              let scalar = Unicode.Scalar(value) else { return nil }
        return MDIGlyph(character: Character(scalar))
    }
}
