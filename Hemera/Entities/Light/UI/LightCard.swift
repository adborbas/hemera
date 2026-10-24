import SwiftUI
import Mortar

struct LightCard: View {
    var viewModel: LightCardViewModel
    @Environment(\.isMediumTile) private var isMediumTile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var litAppearance = LitAppearance()

    /// Unanimated: the glyph can only snap, and a fading circle under an off glyph looks broken.
    private var isLit: Bool { litAppearance.isLit(whenOn: viewModel.isOn) }

    private var showsBrightnessFill: Bool { isMediumTile && viewModel.isDimmable }

    /// Not zeroed when off only because the glow hides the lit layer and retracts the fill with
    /// it. Without a glow there is nothing to hide it, so it has to go.
    private var fillFraction: CGFloat {
        guard viewModel.isOn || !reduceMotion else { return 0 }
        return CGFloat(viewModel.brightness) / 255.0
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
            guard litAppearance.observe(isOn: viewModel.isOn, glowing: !reduceMotion) else { return }
            // Ends the hold even when cancelled, or leaving mid-hold latches the card lit.
            try? await Task.sleep(for: .seconds(Mortar.Motion.glowRetreatDuration))
            litAppearance.endHold()
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
