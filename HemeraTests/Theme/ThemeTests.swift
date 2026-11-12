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
    func position_ofAFieldColour_isWhereItWasPicked(family: ThemeFamily) {
        // The editor reopens with the handle where the user left it.
        let hue = family == .greyscale ? 0 : 0.3
        let position = family.position(of: family.color(hue: hue, radius: 0.6))

        #expect(abs(position.hue - hue) < 0.0001)
        #expect(abs(position.radius - 0.6) < 0.0001)
    }
}
