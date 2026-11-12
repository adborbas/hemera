import Foundation

/// The app's background look. There is always exactly one.
enum Theme: Equatable, Sendable {
    case none
    case gradient(Gradient)

    struct Gradient: Equatable, Sendable {
        /// Where a new Gradient starts: low enough to read as a tint.
        static let defaultIntensity = 0.15 / 0.55

        var color: ThemeColor
        /// 0...1, eased into an opacity only when drawing.
        var intensity: Double
        /// Which editor page the colour came from; only a hint, the colour is the truth.
        var family: ThemeFamily?
    }
}

/// A colour as the user saw it in the editor, each component 0...1.
struct ThemeColor: Codable, Equatable, Sendable {
    var hue: Double
    var saturation: Double
    var brightness: Double
}

/// A group of colours that share a character; also how the editor's colour field maps to a colour.
enum ThemeFamily: String, Codable, CaseIterable, Sendable {
    case bright, pastel, muted, greyscale

    /// `hue` is the angle on the field and `radius` the distance from its centre, both 0...1.
    func color(hue: Double, radius: Double) -> ThemeColor {
        switch self {
        case .bright: ThemeColor(hue: hue, saturation: radius, brightness: 1)
        case .pastel: ThemeColor(hue: hue, saturation: radius * 0.45, brightness: 1)
        case .muted: ThemeColor(hue: hue, saturation: radius * 0.6, brightness: 0.55)
        case .greyscale: ThemeColor(hue: 0, saturation: 0, brightness: 0.15 + 0.85 * (1 - radius))
        }
    }

    /// The point on this family's field nearest to `color`.
    func position(of color: ThemeColor) -> (hue: Double, radius: Double) {
        let radius = switch self {
        case .bright: color.saturation
        case .pastel: color.saturation / 0.45
        case .muted: color.saturation / 0.6
        case .greyscale: 1 - (color.brightness - 0.15) / 0.85
        }
        return (self == .greyscale ? 0 : color.hue, min(max(radius, 0), 1))
    }

    var presets: [ThemeColor] {
        if self == .greyscale {
            return (0..<8).map { color(hue: 0, radius: 0.1 + Double($0) * 0.11) }
        }
        return Self.presetHues.map { color(hue: $0, radius: 0.8) }
    }

    /// Index into `presets` of the preset that is `color`, if any.
    func presetIndex(matching color: ThemeColor) -> Int? {
        presets.firstIndex {
            abs($0.hue - color.hue) < 0.001
                && abs($0.saturation - color.saturation) < 0.001
                && abs($0.brightness - color.brightness) < 0.001
        }
    }

    /// The family whose field comes nearest to `color`; a near-tie goes to the narrower field.
    static func nearest(to color: ThemeColor) -> ThemeFamily {
        let narrowestFirst: [ThemeFamily] = [.greyscale, .pastel, .muted, .bright]
        return narrowestFirst.min { $0.distance(to: color) < $1.distance(to: color) - 0.0001 } ?? .bright
    }

    private static let presetHues = [0.0, 0.07, 0.13, 0.36, 0.5, 0.6, 0.72, 0.86]

    /// Squared sRGB distance from `color` to the nearest colour on this family's field.
    private func distance(to color: ThemeColor) -> Double {
        let position = position(of: color)
        let nearest = self.color(hue: position.hue, radius: position.radius)
        return zip(nearest.rgb, color.rgb).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
    }
}

// MARK: - Codable

/**
 Tolerant on purpose: an unknown kind loads as None and an unknown family as `nil`, so a newer
 build's theme never resets the whole settings document.
*/
extension Theme: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind
    }

    private enum Kind: String, Codable {
        case none, gradient
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if (try? container.decode(Kind.self, forKey: .kind)) == .gradient {
            self = .gradient(try Gradient(from: decoder))
        } else {
            self = .none
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(Kind.none, forKey: .kind)
        case .gradient(let gradient):
            try container.encode(Kind.gradient, forKey: .kind)
            try gradient.encode(to: encoder)
        }
    }
}

extension Theme.Gradient: Codable {

    private enum CodingKeys: String, CodingKey {
        case color, intensity, family
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = try container.decode(ThemeColor.self, forKey: .color)
        intensity = try container.decode(Double.self, forKey: .intensity)
        family = try? container.decodeIfPresent(ThemeFamily.self, forKey: .family)
    }
}
