import SwiftUI

extension View {
    /// The grey card behind a selected menu row or pill.
    public func selectionFill(_ isSelected: Bool) -> some View {
        background(isSelected ? PlatformColor.secondarySystemFill : .clear, in: .rect(cornerRadius: Mortar.Radii.m))
    }
}
