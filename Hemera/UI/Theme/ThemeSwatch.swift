import Mortar
import SwiftUI

struct ThemeSwatch: View {
    /// `nil` is the "None" swatch.
    let color: Color?
    var isSelected = false

    var body: some View {
        Circle()
            .fill(color ?? PlatformColor.systemBackground)
            .overlay {
                if color == nil {
                    Circle().stroke(.secondary, lineWidth: 1)
                    Rectangle().fill(.secondary).frame(width: 1.5).rotationEffect(.degrees(45))
                }
            }
            .frame(width: 26, height: 26)
            .padding(2)
            .overlay(Circle().stroke(.primary, lineWidth: 2).opacity(isSelected ? 1 : 0))
    }
}

extension ThemeSwatch {
    /// The theme's colour as designed, or the None swatch.
    init(theme: Theme, isSelected: Bool = false) {
        if case .gradient(let gradient) = theme {
            self.init(color: gradient.color.swiftUIColor, isSelected: isSelected)
        } else {
            self.init(color: nil, isSelected: isSelected)
        }
    }
}
