import SwiftUI
import Mortar

struct LightCard: View {
    var viewModel: LightCardViewModel
    @Environment(\.isMediumTile) private var isMediumTile

    private var fillFraction: CGFloat {
        guard viewModel.isOn else { return 0 }
        return CGFloat(viewModel.brightness) / 255.0
    }

    var body: some View {
        EntityCard(tintColor: viewModel.tintColor, isActive: viewModel.isOn) {
            CardIcon(iconName: viewModel.iconName,
                     backgroundColor: viewModel.iconBackgroundColor) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.toggle()
            }
        } label: {
            CardLabel(title: viewModel.name,
                      subtitle: viewModel.isOn ? Localization.on : Localization.off,
                      accessibilityIdentifier: viewModel.id)
        } backgroundOverlay: {
            if isMediumTile && viewModel.isDimmable {
                CardFillOverlay(fraction: fillFraction, fillColor: viewModel.tintColor, anchor: .bottom)
            }
        }
        .unavailableStyle(viewModel.isAvailable)
        .animation(Mortar.Motion.springNormal, value: viewModel.isOn)
        .animation(Mortar.Motion.springNormal, value: fillFraction)
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
