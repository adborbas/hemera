import SwiftUI

/// An SF Symbol or MDI glyph on a grey circle, the label of a control panel's round buttons and menus.
public struct CircleIconLabel: View {
    private enum Icon {
        case system(String)
        case mdi(String)
    }

    private let icon: Icon
    private let color: Color

    public init(systemImage: String, color: Color) {
        self.icon = .system(systemImage)
        self.color = color
    }

    /// - Parameter mdiIcon: a Material Design Icon name as Home Assistant writes it, e.g. `"mdi:play"`.
    public init(mdiIcon: String, color: Color) {
        self.icon = .mdi(mdiIcon)
        self.color = color
    }

    public var body: some View {
        glyph
            .foregroundStyle(color)
            .frame(width: Mortar.IconSize.m, height: Mortar.IconSize.m)
            .background {
                Circle().fill(PlatformColor.systemGray5)
            }
    }

    @ViewBuilder
    private var glyph: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.title2)
        case .mdi(let name):
            MDIIcon(name: name, size: Mortar.IconSize.m / 2)
        }
    }
}
