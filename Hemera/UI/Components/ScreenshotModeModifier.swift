import SwiftUI

extension View {
    @ViewBuilder
    func applyUnlessScreenshotMode<V: View>(_ transform: (Self) -> V) -> some View {
        if CommandLine.arguments.contains("-screenshotMode") {
            self
        } else {
            transform(self)
        }
    }
}
