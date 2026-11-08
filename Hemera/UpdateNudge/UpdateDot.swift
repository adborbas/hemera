import Mortar
import SwiftUI

/// Marks the way to Settings while an App Store update is due.
struct UpdateDot: View {
    var body: some View {
        Circle()
            .fill(Color.warning)
            .frame(width: Mortar.Spacing.m, height: Mortar.Spacing.m)
            .overlay(Circle().stroke(PlatformColor.systemBackground, lineWidth: Mortar.strokeWidth))
    }
}
