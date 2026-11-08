import SwiftUI

/// Icon only, in a minimum-size tap target.
public struct IconButtonLabelStyle: LabelStyle {
    public func makeBody(configuration: Configuration) -> some View {
        Label(configuration)
            .labelStyle(.iconOnly)
            .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
            .contentShape(.rect)
    }
}

extension LabelStyle where Self == IconButtonLabelStyle {
    public static var mortarIconButton: IconButtonLabelStyle { IconButtonLabelStyle() }
}
