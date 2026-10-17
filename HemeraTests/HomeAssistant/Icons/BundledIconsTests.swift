import Foundation
import Mortar
import Testing
@testable import Hemera

@MainActor
struct BundledIconsTests {

    private let provider = MDIFontIconProvider()

    // MARK: - Font

    @Test func glyph_resolvesFromTheVendoredFont() {
        #expect(provider.glyph(named: "mdi:lightbulb") != nil)
        #expect(provider.glyph(named: "garage") != nil)
    }

    @Test func glyph_unknownName_returnsNil() {
        #expect(provider.glyph(named: "mdi:definitely-not-an-icon") == nil)
    }

    @Test func glyph_unsupportedIconPack_returnsNil() {
        #expect(provider.glyph(named: "phu:floor-lamp") == nil)
    }

    // MARK: - Translations

    @Test func translations_areShippedInTheBundle() throws {
        let translations = try #require(IconTranslations.bundled())
        #expect(translations.entry(domain: "light", deviceClass: nil)?.defaultIcon == "mdi:lightbulb")
    }

    /**
     Every icon Home Assistant's shipped translations can produce must resolve against the vendored
     font. With the full set bundled this should be total — a failure means the font and the
     translations were generated from mismatched Material Design Icons versions.
    */
    @Test func everyIconNameInTheShippedTranslations_resolves() throws {
        let translations = try #require(IconTranslations.bundled())

        var referenced: Set<String> = []
        func collect(_ entry: IconTranslations.Entry) {
            entry.defaultIcon.map { referenced.insert($0) }
            entry.state?.values.forEach { referenced.insert($0) }
            entry.stateAttributes?.values.forEach(collect)
        }
        translations.resources.values.flatMap(\.values).forEach(collect)

        #expect(!referenced.isEmpty)
        let missing = referenced.filter { provider.glyph(named: $0) == nil }
        #expect(missing.isEmpty, "Unresolvable: \(missing.sorted().joined(separator: ", "))")
    }

    /// Icons the app names itself: area fallbacks and the transient card states.
    @Test func appSuppliedIconNames_resolve() {
        for name in ["mdi:texture-box", "mdi:tray", "mdi:stop", "mdi:check-circle"] {
            #expect(provider.glyph(named: name) != nil, "Unresolvable: \(name)")
        }
    }

    /**
     Demo mode runs without a Home Assistant connection and is what the App Store screenshots are
     captured from, so every icon it hardcodes has to resolve offline. This is the check that was
     missing when `mdi:timer` and `mdi:wifi` shipped unbundled.
    */
    @Test func everyIconNameInDemoData_resolves() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Hemera/Demo/DemoDataProvider.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        let names = source.matches(of: /icon: "(mdi:[a-z0-9-]+)"/).map { String($0.1) }
        #expect(!names.isEmpty)

        let missing = names.filter { provider.glyph(named: $0) == nil }
        #expect(missing.isEmpty, "Unresolvable: \(Set(missing).sorted().joined(separator: ", "))")
    }
}
