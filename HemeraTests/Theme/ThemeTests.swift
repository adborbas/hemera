import Testing
@testable import Hemera

@MainActor
struct ThemeTests {

    @Test(arguments: ThemeFamily.allCases)
    func presetIndex_findsEachPresetOnlyInItsOwnFamily(family: ThemeFamily) {
        // A selected preset must light up once, on the page it belongs to.
        #expect(family.presets.count == 8)
        for (index, preset) in family.presets.enumerated() {
            #expect(family.presetIndex(matching: preset) == index)
            for other in ThemeFamily.allCases where other != family {
                #expect(other.presetIndex(matching: preset) == nil)
            }
        }
    }

    @Test(arguments: ThemeFamily.allCases)
    func nearest_ofEachPreset_isItsOwnFamily(family: ThemeFamily) {
        // A Gradient stored without its family still reopens on the page that shows its preset selected.
        for preset in family.presets {
            #expect(ThemeFamily.nearest(to: preset) == family)
        }
    }

    @Test func nearest_ofAColourOffEveryField_isTheClosestField() {
        // A dark saturated red is on no page; the muted page is the one that comes close to it.
        let darkRed = ThemeColor(hue: 0, saturation: 0.9, brightness: 0.5)

        #expect(ThemeFamily.nearest(to: darkRed) == .muted)
    }

    @Test(arguments: ThemeFamily.allCases)
    func position_ofAFieldColour_isWhereItWasPicked(family: ThemeFamily) {
        // The editor reopens with the handle where the user left it.
        let hue = family == .greyscale ? 0 : 0.3
        let position = family.position(of: family.color(hue: hue, radius: 0.6))

        #expect(abs(position.hue - hue) < 0.0001)
        #expect(abs(position.radius - 0.6) < 0.0001)
    }

    @Test(arguments: [ThemeFamily.bright, .pastel, .muted])
    func name_ofEachColourPreset_isTheHueItWasBuiltOn(family: ThemeFamily) {
        // VoiceOver users tell presets apart by name, so each one on a page must sound different.
        let names = family.presets.map { family.name(of: $0) }

        #expect(names == HueName.allCases.map { .hue($0) })
    }

    @Test func name_ofGreyscalePresets_isEachOnesDistinctBrightness() {
        // Greys share no hue, so their brightness is what tells them apart, from lightest to darkest.
        let percents = ThemeFamily.greyscale.presets.map { color -> Int in
            guard case .brightness(let percent) = ThemeFamily.greyscale.name(of: color) else { return -1 }
            return percent
        }

        #expect(percents == percents.sorted(by: >))
        #expect(Set(percents).count == 8)
        #expect(percents.allSatisfy { (15...100).contains($0) })
    }

    @Test func nearestHueName_wrapsAroundTheWheel() {
        // The hue control speaks red on both sides of 0, not pink just below 1.
        #expect(HueName.nearest(to: 0) == .red)
        #expect(HueName.nearest(to: 0.98) == .red)
        #expect(HueName.nearest(to: 1) == .red)
        #expect(HueName.nearest(to: 0.02) == .red)
        #expect(HueName.nearest(to: 0.9) == .pink)
    }
}
