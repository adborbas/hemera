import Mortar
import SwiftUI

/// A colour and the opacity it is laid over the scheme's base at.
struct ThemePaint: Equatable, Sendable {
    var color: ThemeColor
    var alpha: Double
}

extension Theme.Gradient {

    /// The background for `scheme`, shifted until cards stand apart from it.
    func painted(in scheme: ColorScheme) -> ThemePaint {
        let dark = scheme == .dark
        var paint = ThemePaint(color: color, alpha: ThemeMaths.alpha(intensity: intensity))
        for _ in 0..<40 where ThemeMaths.cardContrast(paint, in: scheme) < ThemeMaths.minimumCardContrast {
            if dark && paint.color.brightness < 1 {
                paint.color.brightness = min(1, paint.color.brightness + 0.05)
            } else if !dark && paint.color.brightness > 0.45 {
                paint.color.brightness -= 0.04
            } else {
                paint.alpha = min(0.88, paint.alpha + 0.03)
            }
        }
        return paint
    }

    /// The dark paint at 60% over true black, dimmed until the clock keeps 7:1 on its lightest point.
    var screensaverPainted: ThemePaint {
        var paint = painted(in: .dark)
        paint.alpha *= 0.6
        while paint.alpha > 0.02 && ThemeMaths.clockContrast(paint) < ThemeMaths.minimumClockContrast {
            paint.alpha = max(0, paint.alpha - 0.02)
        }
        return paint
    }
}

enum ThemeMaths {

    static let minimumCardContrast = 1.5
    static let screensaverClockOpacity = 0.85
    static let minimumClockContrast = 7.0

    /// Keeps the low end of the intensity range subtle.
    static func alpha(intensity: Double) -> Double {
        0.2 + 0.68 * intensity * intensity
    }

    /// What the gradient is laid over: near-black in dark, white in light.
    static func base(in scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.075 : 1
    }

    /// WCAG contrast between the background composited over its base and the card colour.
    static func cardContrast(_ paint: ThemePaint, in scheme: ColorScheme) -> Double {
        let base = base(in: scheme)
        let background = paint.color.rgb.map { base * (1 - paint.alpha) + $0 * paint.alpha }
        return contrast(background, cardColor(in: scheme))
    }

    /// WCAG contrast of the clock, white at `screensaverClockOpacity`, over the mesh's lightest point.
    static func clockContrast(_ paint: ThemePaint) -> Double {
        let lightest = paint.color.rgb.map { ($0 * 0.75 + 0.25) * paint.alpha }
        let clock = lightest.map { screensaverClockOpacity + $0 * (1 - screensaverClockOpacity) }
        return contrast(clock, lightest)
    }

    /// WCAG 2 contrast ratio between two sRGB colours.
    static func contrast(_ a: [Double], _ b: [Double]) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func cardColor(in scheme: ColorScheme) -> [Double] {
        scheme == .dark ? darkCard : lightCard
    }

    private static let lightCard = resolved(PlatformColor.secondarySystemBackground, in: .light)
    private static let darkCard = resolved(PlatformColor.secondarySystemBackground, in: .dark)

    private static func resolved(_ color: Color, in scheme: ColorScheme) -> [Double] {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let resolved = color.resolve(in: environment)
        return [resolved.red, resolved.green, resolved.blue].map(Double.init)
    }

    private static func luminance(_ rgb: [Double]) -> Double {
        let linear = rgb.map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}

// MARK: - Mesh

extension ThemeMaths {

    static let meshPoints: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.5], [0.6, 0.4], [1, 0.5],
        [0, 1], [0.5, 1], [1, 1],
    ]

    /// One colour for each of `meshPoints`; `clockContrast` assumes the lightest is 25% towards white.
    static func meshColors(_ color: Color) -> [Color] {
        let light = color.mix(with: .white, by: 0.25)
        let dark = color.mix(with: .black, by: 0.25)
        return [light, color, color, color, color, dark, color, dark, dark]
    }
}

extension ThemeColor {

    var swiftUIColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// sRGB components, 0...1.
    var rgb: [Double] {
        let h = (hue - hue.rounded(.down)) * 6, i = Int(h) % 6, f = h - h.rounded(.down)
        let (s, b) = (saturation, brightness)
        let p = b * (1 - s), q = b * (1 - s * f), t = b * (1 - s * (1 - f))
        return [[b, t, p], [q, b, p], [p, b, t], [p, q, b], [t, p, b], [b, p, q]][i]
    }
}
