import Foundation

/**
 The temperature unit demo data speaks. Fixtures are written in Celsius and converted once here,
 so a sensor's unit, its state and its history can never disagree about what the numbers mean.
*/
enum DemoTemperature {

    static var unit: UnitTemperature { Self.unit(for: .current) }

    /// Only the US measurement system means Fahrenheit; the UK is imperial but reports Celsius.
    static func unit(for locale: Locale) -> UnitTemperature {
        locale.measurementSystem == .us ? .fahrenheit : .celsius
    }

    static var symbol: String { Self.unit.symbol }

    static func converted(_ celsius: Double, to unit: UnitTemperature = Self.unit) -> Double {
        Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: unit).value
    }

    /**
     A sensor's `state`, which Home Assistant reports as a bare number. Formatted against POSIX
     because callers parse it back with `Double`, which rejects a comma decimal separator.
    */
    static func state(_ celsius: Double, in unit: UnitTemperature = Self.unit) -> String {
        Self.converted(celsius, to: unit)
            .formatted(.number.precision(.fractionLength(1)).locale(Self.parsableLocale))
    }

    /// A humidity state: no conversion, but the same POSIX formatting so `Double` can read it.
    static func plainState(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Self.parsableLocale))
    }

    private static let parsableLocale = Locale(identifier: "en_US_POSIX")
}
