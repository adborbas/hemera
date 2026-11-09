import SwiftUI
import Mortar

struct ClimateCard: View {
    var viewModel: ClimateCardViewModel

    var body: some View {
        EntityCard(tintColor: viewModel.tintColor, isActive: viewModel.isActive) {
            CardIcon(icon: viewModel.iconName,
                     backgroundColor: viewModel.iconBackgroundColor,
                     actionLabel: viewModel.isAvailable ? (viewModel.isOff ? Localization.turnOn : Localization.turnOff) : nil) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.togglePower()
            }
            .accessibilityIdentifier("\(viewModel.id).icon")
        } label: {
            CardLabel(title: viewModel.name,
                      subtitle: viewModel.statusText,
                      accessibilityIdentifier: viewModel.id)
        }
        .unavailableStyle(viewModel.isAvailable)
        .animation(Mortar.Motion.springNormal, value: viewModel.hvacMode)
        .animation(Mortar.Motion.springNormal, value: viewModel.hvacAction)
    }
}

private extension ClimateCard {
    enum Localization {
        static let turnOn = String(localized: "Turn on", comment: "VoiceOver name for the card icon that turns the thermostat on")
        static let turnOff = String(localized: "Turn off", comment: "VoiceOver name for the card icon that turns the thermostat off")
    }
}

#if DEBUG
#Preview {
    VStack {
        ClimateCard(viewModel: .previewHeating)
        ClimateCard(viewModel: .previewCooling)
        ClimateCard(viewModel: .previewOff)
    }
    .padding(Mortar.Spacing.m)
}

fileprivate extension ClimateCardViewModel {
    static var previewHeating: ClimateCardViewModel {
        let entity = ClimateEntity(
            entityId: "climate.heater", name: "Heater", state: .heat,
            hvacAction: .heating, currentTemperature: 19.8, temperature: 21,
            hvacModesRaw: ["off", "heat"]
        )
        return ClimateCardViewModel(climate: entity, controller: PreviewClimateController())
    }

    static var previewCooling: ClimateCardViewModel {
        let entity = ClimateEntity(
            entityId: "climate.ac", name: "AC", state: .cool,
            hvacAction: .cooling, currentTemperature: 24.5, temperature: 22,
            hvacModesRaw: ["off", "cool", "heat", "auto"]
        )
        return ClimateCardViewModel(climate: entity, controller: PreviewClimateController())
    }

    static var previewOff: ClimateCardViewModel {
        let entity = ClimateEntity(
            entityId: "climate.off", name: "Thermostat", state: .off,
            hvacAction: .off, currentTemperature: 21.3,
            hvacModesRaw: ["off", "heat", "cool"]
        )
        return ClimateCardViewModel(climate: entity, controller: PreviewClimateController())
    }
}

private final class PreviewClimateController: ClimateControlling {
    func setHVACMode(_ id: String, mode: String) async {}
    func setTemperature(_ id: String, temperature: Double) async {}
    func setTemperatureRange(_ id: String, low: Double, high: Double) async {}
    func setFanMode(_ id: String, mode: String) async {}
    func setSwingMode(_ id: String, mode: String) async {}
    func setPresetMode(_ id: String, mode: String) async {}
    func setHumidity(_ id: String, humidity: Double) async {}
    func turnOnClimate(_ id: String) async {}
    func turnOffClimate(_ id: String) async {}
}
#endif
