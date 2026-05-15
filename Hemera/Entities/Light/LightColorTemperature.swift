import SwiftUI

enum LightColorTemperature {
    /// A 4-stop linear gradient representing the color temperature spectrum
    /// from warm amber (~2000K) to cool daylight (~6500K).
    static let gradientColors: [Color] = [
        Color(red: 1.0, green: 0.58, blue: 0.16),  // ~2000K warm amber
        Color(red: 1.0, green: 0.82, blue: 0.55),  // ~2700K warm white
        Color(red: 1.0, green: 0.93, blue: 0.82),  // ~4000K neutral white
        Color(red: 0.82, green: 0.88, blue: 1.0)    // ~6500K cool daylight
    ]
}
