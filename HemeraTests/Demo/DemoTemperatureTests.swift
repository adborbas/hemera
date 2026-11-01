import Foundation
import Testing
@testable import Hemera

struct DemoTemperatureTests {

    // MARK: - Unit for a locale

    @Test
    func unit_usLocale_isFahrenheit() {
        #expect(DemoTemperature.unit(for: Locale(identifier: "en_US")) == .fahrenheit)
    }

    /// The UK is imperial for distance but reports temperature in Celsius.
    @Test
    func unit_ukLocale_isCelsius() {
        #expect(DemoTemperature.unit(for: Locale(identifier: "en_GB")) == .celsius)
    }

    @Test
    func unit_metricLocale_isCelsius() {
        #expect(DemoTemperature.unit(for: Locale(identifier: "hu_HU")) == .celsius)
    }

    // MARK: - Conversion

    @Test
    func converted_toFahrenheit_appliesTheCelsiusScale() {
        #expect(abs(DemoTemperature.converted(20, to: .fahrenheit) - 68) < 0.001)
        #expect(abs(DemoTemperature.converted(0, to: .fahrenheit) - 32) < 0.001)
    }

    @Test
    func converted_toCelsius_leavesTheFigureAlone() {
        #expect(abs(DemoTemperature.converted(21.4, to: .celsius) - 21.4) < 0.001)
    }

    // MARK: - State string

    /**
     `AreaDisplayHelpers.climateSummary` parses a state with `Double`, which rejects a comma
     decimal separator, so the state must not follow a comma-decimal locale.
    */
    @Test
    func state_isParsableByDouble() {
        #expect(Double(DemoTemperature.state(22, in: .celsius)) == 22.0)
        #expect(Double(DemoTemperature.state(20, in: .fahrenheit)) == 68.0)
    }

    @Test
    func symbol_matchesTheUnit() {
        #expect(UnitTemperature.celsius.symbol == "°C")
        #expect(UnitTemperature.fahrenheit.symbol == "°F")
    }
}
