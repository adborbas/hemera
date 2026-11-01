import Foundation

/// Pads the data's own range proportionally so small real variation stays legible.
enum ClimateSampleYDomain {

    /// Fixed half-pad used only when every sample's mean is identical.
    private static let zeroSpreadPadding: Double = 0.5

    /// The Y domain to chart: the data's min...max padded about 20% of the spread each side.
    static func domain(forValues values: [Double]) -> ClosedRange<Double> {
        guard let first = values.first else { return 0...1 }

        let lowest = values.min() ?? first
        let highest = values.max() ?? first
        let spread = highest - lowest

        if spread > 0 {
            let pad = spread * 0.2
            return (lowest - pad)...(highest + pad)
        }

        return (first - zeroSpreadPadding)...(first + zeroSpreadPadding)
    }
}
