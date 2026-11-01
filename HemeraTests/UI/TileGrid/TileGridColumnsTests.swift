import Foundation
import Testing
@testable import Hemera

@MainActor
struct TileGridColumnsTests {

    // MARK: - Helpers

    /// Rendered width of a `.medium` tile, which spans 2 grid columns plus the gap between them.
    private func mediumTileWidth(gridWidth: CGFloat, columns: Int) -> CGFloat {
        let available = gridWidth
            - (TileGridConstants.padding * 2)
            - (CGFloat(columns - 1) * TileGridConstants.columnSpacing)
        return (available / CGFloat(columns)) * 2 + TileGridConstants.columnSpacing
    }

    // MARK: - Compact width

    @Test func columns_compactPortrait_isFour() {
        #expect(TileGridConstants.columns(for: CGSize(width: 402, height: 874), isCompactWidth: true) == 4)
    }

    @Test func columns_compactLandscape_isFour() {
        #expect(TileGridConstants.columns(for: CGSize(width: 874, height: 402), isCompactWidth: true) == 4)
    }

    // MARK: - Regular width

    @Test func columns_regularPortrait_isEight() {
        #expect(TileGridConstants.columns(for: CGSize(width: 1024, height: 1366), isCompactWidth: false) == 8)
    }

    @Test func columns_iPadProLandscape_isTwelve() {
        #expect(TileGridConstants.columns(for: CGSize(width: 1366, height: 1024), isCompactWidth: false) == 12)
    }

    /// iPad mini 5 is 1024pt in landscape, too narrow for 12 columns to stay square.
    @Test func columns_iPadMini5Landscape_isEight() {
        #expect(TileGridConstants.columns(for: CGSize(width: 1024, height: 768), isCompactWidth: false) == 8)
    }

    /// The 10.2" iPad sits exactly on the threshold at 1080pt.
    @Test func columns_iPad102Landscape_isTwelve() {
        #expect(TileGridConstants.columns(for: CGSize(width: 1080, height: 810), isCompactWidth: false) == 12)
    }

    // MARK: - iPhone Duo

    /// The Duo's inner display is regular width but only 951pt across, too narrow for 12 columns.
    @Test func columns_duoInnerLandscape_isEightNotTwelve() {
        #expect(TileGridConstants.columns(for: CGSize(width: 951, height: 669), isCompactWidth: false) == 8)
    }

    @Test func columns_narrowRegularPortrait_isEight() {
        #expect(TileGridConstants.columns(for: CGSize(width: 669, height: 951), isCompactWidth: false) == 8)
    }

    @Test func columns_duoOuterLandscape_isFour() {
        #expect(TileGridConstants.columns(for: CGSize(width: 678, height: 466), isCompactWidth: true) == 4)
    }

    // MARK: - Tile geometry

    /**
     A medium tile is a fixed 168pt tall, so anything narrower reads as a sliver. This is the bar
     `wideGridMinWidth` encodes; the 12-column ladder broke it on the Duo's inner display.
    */
    @Test(arguments: [
        (CGSize(width: 466, height: 678), true),    // Duo outer, portrait
        (CGSize(width: 678, height: 466), true),    // Duo outer, landscape
        (CGSize(width: 951, height: 669), false),   // Duo inner, landscape
        (CGSize(width: 402, height: 874), true),    // iPhone, portrait
        (CGSize(width: 874, height: 402), true),    // iPhone, landscape
        (CGSize(width: 1024, height: 768), false),  // iPad mini 5, landscape
        (CGSize(width: 1080, height: 810), false),  // iPad 10.2", landscape
        (CGSize(width: 1366, height: 1024), false), // iPad Pro 13", landscape
        (CGSize(width: 1024, height: 1366), false)  // iPad Pro 13", portrait
    ])
    func mediumTile_isNeverNarrowerThanItIsTall(size: CGSize, isCompactWidth: Bool) {
        let columns = TileGridConstants.columns(for: size, isCompactWidth: isCompactWidth)
        let height = (TileGridConstants.smallTileHeight * 2) + TileGridConstants.rowSpacing
        #expect(mediumTileWidth(gridWidth: size.width, columns: columns) >= height)
    }
}
