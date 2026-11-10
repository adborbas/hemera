import Mortar
import SwiftData
import SwiftUI

/// An entity's control panel, with an info button that pushes its device's Sensors page.
struct EntityOverlay: View {
    let viewModel: any EntityCardViewModel
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var showsSensors = false

    var body: some View {
        let sensors = viewModel.deviceId.map { DeviceSensorsViewModel(deviceId: $0, context: modelContext) }

        NavigationStack {
            viewModel.makeOverlayView(isPresented: $isPresented)
                .toolbar(.hidden, for: .navigationBar)
                .containerBackground(.clear, for: .navigation)
                .environment(\.entityControlPanelInfo, sensors?.hasSensors == true ? info : nil)
                .navigationDestination(isPresented: $showsSensors) {
                    if let sensors { DeviceSensorsView(viewModel: sensors) }
                }
        }
    }

    private var info: EntityControlPanelInfo {
        EntityControlPanelInfo(label: Localization.sensors) { showsSensors = true }
    }
}

// MARK: - Localization

private extension EntityOverlay {
    enum Localization {
        static let sensors = String(
            localized: "Sensors",
            comment: "VoiceOver label for the info button on a control panel that opens the device's sensors"
        )
    }
}
