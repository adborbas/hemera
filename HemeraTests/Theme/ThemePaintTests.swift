import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct ThemePaintTests {

    /// Every preset, plus a grid over each family's whole colour field.
    static let colors: [ThemeColor] = ThemeFamily.allCases.flatMap { family in
        family.presets + stride(from: 0.0, through: 1, by: 1.0 / 24).flatMap { hue in
            stride(from: 0.0, through: 1, by: 0.1).map { family.color(hue: hue, radius: $0) }
        }
    }

    static let intensities = Array(stride(from: 0.0, through: 1, by: 0.05))

    static var gradients: [Theme.Gradient] {
        colors.flatMap { color in intensities.map { Theme.Gradient(color: color, intensity: $0) } }
    }

    // MARK: - Contrast Formula

    @Test func contrast_blackOnWhite_isTwentyOne() {
        #expect(abs(ThemeMaths.contrast([0, 0, 0], [1, 1, 1]) - 21) < 0.001)
    }

    @Test func cardColor_isTheSystemCardGreyPerScheme() {
        // The sweeps are only as good as the card colour they compare against.
        let light = ThemeMaths.cardColor(in: .light).map { ($0 * 255).rounded() }
        let dark = ThemeMaths.cardColor(in: .dark).map { ($0 * 255).rounded() }

        #expect(light == [242, 242, 247])
        #expect(dark == [28, 28, 30])
    }

    // MARK: - Sweeps

    @Test(arguments: [ColorScheme.light, .dark])
    func painted_everyThemeAndIntensity_keepsCardsApart(scheme: ColorScheme) {
        let failures = Self.gradients.filter {
            ThemeMaths.cardContrast($0.painted(in: scheme), in: scheme) < ThemeMaths.minimumCardContrast
        }

        #expect(failures.isEmpty, "\(failures.count) below 1.5:1, first: \(String(describing: failures.first))")
    }

    @Test func screensaverPainted_everyThemeAndIntensity_keepsClockReadable() {
        let failures = Self.gradients.filter {
            ThemeMaths.clockContrast($0.screensaverPainted) < ThemeMaths.minimumClockContrast
        }

        #expect(failures.isEmpty, "\(failures.count) below 7:1, first: \(String(describing: failures.first))")
    }
}
