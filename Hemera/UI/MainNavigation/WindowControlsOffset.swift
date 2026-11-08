import SwiftUI

/// Moves top-leading content clear of the iPadOS window controls.
struct WindowControlsOffset: ViewModifier {
    /// Shrinks from the leading edge instead of sliding, so the content's trailing end stays put.
    var sizeToFit = false

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.containerCornerOffset(.leading, sizeToFit: sizeToFit)
        } else {
            content
        }
    }
}
