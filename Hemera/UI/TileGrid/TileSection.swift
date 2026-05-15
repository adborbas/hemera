import Foundation
import TileGridEngine

/// A section of tiles displayed in a TiledGrid.
struct TileSection: Identifiable {
    let id = UUID()
    var title: String?
    var tiles: [Tile]
    var temperature: String?
    var humidity: String?
    var tag: String?

    var climateLabel: String? {
        let parts = [temperature, humidity].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
