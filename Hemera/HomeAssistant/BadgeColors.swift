import SwiftUI

/**
 The avatar's fill and text, derived from the user's primary colour as Home Assistant's web app does it
 (`apply_themes_on_element.ts`): 18 Lab lightness brighter, with dark or white text by WCAG contrast.
*/
struct BadgeColors: Equatable {
    struct RGB: Equatable {
        let red: Int
        let green: Int
        let blue: Int

        var color: Color {
            Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
        }
    }

    /// Home Assistant's own badge colours when the user picked no primary colour.
    static let standard = BadgeColors(fill: RGB(red: 0xB3, green: 0xE5, blue: 0xFC), text: darkText)

    private static let darkText = RGB(red: 0x21, green: 0x21, blue: 0x21)
    private static let white = RGB(red: 0xFF, green: 0xFF, blue: 0xFF)

    let fill: RGB
    let text: RGB
}

extension BadgeColors {
    /// A missing or unreadable `#rrggbb` falls back to `standard`.
    init(primaryColor hex: String?) {
        guard let primary = hex.flatMap(RGB.init(hex:)) else {
            self = .standard
            return
        }
        var lab = primary.lab
        lab.l += 18
        // Unclamped, because Home Assistant measures the contrast before clamping.
        let light = RGB(lab: lab)
        self.init(fill: light.clamped, text: light.contrast(with: Self.darkText) < 6 ? Self.white : Self.darkText)
    }
}

// MARK: - Home Assistant's colour maths (`src/common/color/convert-color.ts`)

private struct Lab {
    var l: Double
    var a: Double
    var b: Double
}

private enum D65 {
    static let x = 0.95047
    static let y = 1.0
    static let z = 1.08883
    static let t0 = 0.137931034
    static let t1 = 0.206896552
    static let t2 = 0.12841855
    static let t3 = 0.008856452
}

private extension BadgeColors.RGB {
    init?(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        self.init(red: value >> 16 & 0xFF, green: value >> 8 & 0xFF, blue: value & 0xFF)
    }

    init(lab: Lab) {
        func toXYZ(_ t: Double) -> Double { t > D65.t1 ? t * t * t : D65.t2 * (t - D65.t0) }
        func toRGB(_ r: Double) -> Int {
            Int((255 * (r <= 0.00304 ? 12.92 * r : 1.055 * pow(r, 1 / 2.4) - 0.055)).rounded())
        }
        let fy = (lab.l + 16) / 116
        let x = D65.x * toXYZ(lab.a.isNaN ? fy : fy + lab.a / 500)
        let y = D65.y * toXYZ(fy)
        let z = D65.z * toXYZ(lab.b.isNaN ? fy : fy - lab.b / 200)
        self.init(
            red: toRGB(3.2404542 * x - 1.5371385 * y - 0.4985314 * z),
            green: toRGB(-0.969266 * x + 1.8760108 * y + 0.041556 * z),
            blue: toRGB(0.0556434 * x - 0.2040259 * y + 1.0572252 * z)
        )
    }

    var lab: Lab {
        func linear(_ c: Int) -> Double {
            let c = Double(c) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        func toLab(_ t: Double) -> Double { t > D65.t3 ? pow(t, 1.0 / 3) : t / D65.t2 + D65.t0 }
        let (r, g, b) = (linear(red), linear(green), linear(blue))
        let x = toLab((0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / D65.x)
        let y = toLab((0.2126729 * r + 0.7151522 * g + 0.072175 * b) / D65.y)
        let z = toLab((0.0193339 * r + 0.119192 * g + 0.9503041 * b) / D65.z)
        return Lab(l: max(0, 116 * y - 16), a: 500 * (x - y), b: 200 * (y - z))
    }

    var clamped: Self {
        func clamp(_ c: Int) -> Int { min(max(c, 0), 255) }
        return Self(red: clamp(red), green: clamp(green), blue: clamp(blue))
    }

    /// WCAG contrast ratio, as culori's `wcagContrast` computes it, so out-of-range channels count too.
    func contrast(with other: Self) -> Double {
        let (l1, l2) = (luminance, other.luminance)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private var luminance: Double {
        func linear(_ c: Int) -> Double {
            let c = Double(c) / 255
            return abs(c) <= 0.04045 ? c / 12.92 : (c < 0 ? -1 : 1) * pow((abs(c) + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
