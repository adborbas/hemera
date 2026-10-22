import SwiftUI
import Mortar

struct LightCard: View {
    var viewModel: LightCardViewModel
    @Environment(\.isMediumTile) private var isMediumTile

    /**
     Holds the card's lit appearance until the glow has retracted into the icon. A bulb that goes
     dark while the card is still washed shows the on and off state at once.
    */
    @State private var staysLit = false
    @State private var hasRendered = false

    /**
     Flipped in one frame, unanimated: the MDI glyph can only snap, so fading the icon's colour
     alongside it would leave an off glyph on an on-coloured circle for the length of the fade.
    */
    private var isLit: Bool { viewModel.isOn || staysLit }

    private var showsBrightnessFill: Bool { isMediumTile && viewModel.isDimmable }

    /**
     Not zeroed when the light is off: the fill sits in the card's lit layer, which the glow hides
     entirely, so leaving it at its level lets the glow retract it as one surface instead of sliding
     it away underneath.
    */
    private var fillFraction: CGFloat {
        CGFloat(viewModel.brightness) / 255.0
    }

    var body: some View {
        EntityCard(tintColor: viewModel.tintColor, isActive: viewModel.isOn, glowsFromIcon: true) {
            CardIcon(icon: viewModel.iconName(lit: isLit),
                     backgroundColor: viewModel.iconBackgroundColor(lit: isLit)) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.toggle()
            }
        } label: {
            CardLabel(title: viewModel.name,
                      subtitle: isLit ? Localization.on : Localization.off,
                      accessibilityIdentifier: viewModel.id)
        } backgroundOverlay: {
            if showsBrightnessFill {
                CardFillOverlay(fraction: fillFraction, fillColor: viewModel.tintColor, anchor: .bottom)
            }
        }
        .unavailableStyle(viewModel.isAvailable)
        .animation(Mortar.Motion.springNormal, value: fillFraction)
        .task(id: viewModel.isOn) {
            defer { hasRendered = true }
            // Turning on, or a first render that is merely showing an already-off light.
            guard hasRendered, !viewModel.isOn else {
                staysLit = false
                return
            }
            staysLit = true
            try? await Task.sleep(for: .seconds(Mortar.Motion.glowRetreatDuration))
            guard !Task.isCancelled else { return }
            staysLit = false
        }
    }
}

private extension LightCard {
    enum Localization {
        static let on = String(localized: "On", comment: "Light entity state shown on card when the light is turned on")
        static let off = String(localized: "Off", comment: "Light entity state shown on card when the light is turned off")
    }
}

#if DEBUG
#Preview {
    VStack {
        LightCard(viewModel: LightCardViewModel.mockLamp(isOn: true))
        LightCard(viewModel: LightCardViewModel.mockLamp(isOn: false))
    }
    .padding(12)
}

fileprivate extension LightCardViewModel {
    static func mockLamp(isOn: Bool) -> LightCardViewModel {
        let light = LightEntity(entityId: "id",
                                  name: "Light",
                                  state: isOn ? .on : .off)
        return LightCardViewModel(light: light, controller: MockLightControlling())
    }
}

private final class MockLightControlling: LightControlling {
    func setLight(_ id: String, on: Bool) async {}
    func setBrightness(_ id: String, to brightness: Int) async {}
    func setColorTemp(_ id: String, to mireds: Int) async {}
    func setHSColor(_ id: String, hue: Double, saturation: Double) async {}
}
#endif
