import Foundation
import Mortar
import SwiftData
import SwiftUI

enum CoverControlMode: String, Hashable {
    case slider
    case buttons

    var iconName: String {
        switch self {
        case .slider: "line.3.horizontal.decrease"
        case .buttons: "arrow.up.and.down"
        }
    }
}

@Observable
@MainActor
final class CoverCardViewModel: Identifiable {
    private(set) var cover: CoverEntity

    nonisolated let id: String
    var name: String { cover.name }
    var isAvailable: Bool { cover.isAvailable }
    var deviceId: String? { cover.deviceId }
    var position: Int? { cover.currentPosition }
    var state: CoverEntity.State { cover.state }

    /**
     Pending-aware position for the slider control only. Everything that reflects
     server truth (the card, subtitle, and `iconTapped`) uses `position` — the
     slider needs the optimistic pending value so it reconciles on failure via
     the observable cooldown expiry without ever showing unconfirmed state on the card.
     */
    var sliderPosition: Int? {
        if cooldown.isSuppressed, let pending = pendingPosition { return pending }
        return cover.currentPosition
    }

    private var pendingPosition: Int?
    private let cooldown: CommitCooldown
    private let controller: CoverControlling
    private(set) var actionTask: Task<Void, Never>?

    var stateDescription: String {
        let localizedState = localizedStateName
        switch state {
        case .open:
            if let position = self.position, position != 100 {
                return Localization.positionAndState(position, localizedState)
            }
            return localizedState
        case .closed, .unknown, .unavailable:
            return localizedState
        case .opening, .closing:
            return Localization.transitioning(localizedState)
        }
    }

    var simpleStateDescription: String {
        localizedStateName
    }

    private var localizedStateName: String {
        switch state {
        case .open:        Localization.open
        case .closed:      Localization.closed
        case .opening:     Localization.opening
        case .closing:     Localization.closing
        case .unknown:     Localization.unknown
        case .unavailable: Localization.unavailable
        }
    }

    var isOpen: Bool {
        switch state {
        case .open, .opening, .closing: true
        case .closed, .unknown, .unavailable: false
        }
    }

    var iconName: String {
        cover.deviceClass.symbolName(for: state)
    }

    var iconBackgroundColor: Color {
        switch state {
        case .open, .opening, .closing:
            .blue
        case .closed, .unknown, .unavailable:
            PlatformColor.systemGray3
        }
    }

    var tintColor: Color { .blue }

    var supportsOpen: Bool { cover.supportedFeatures.contains(.open) }
    var supportsClose: Bool { cover.supportedFeatures.contains(.close) }
    var supportsStop: Bool { cover.supportedFeatures.contains(.stop) }

    var supportedControlModes: [CoverControlMode] {
        var modes: [CoverControlMode] = []
        if cover.supportedFeatures.contains(.setPosition) {
            modes.append(.slider)
        }
        let buttonFeatures: CoverEntity.Features = [.open, .close, .stop]
        if !cover.supportedFeatures.intersection(buttonFeatures).isEmpty {
            modes.append(.buttons)
        }
        return modes
    }

    var preferredControlMode: CoverControlMode? {
        get {
            guard let raw = cover.preferredControlMode else { return nil }
            return CoverControlMode(rawValue: raw)
        }
        set {
            cover.preferredControlMode = newValue?.rawValue
        }
    }

    init(cover: CoverEntity,
         controller: CoverControlling,
         cooldown: CommitCooldown? = nil) {
        self.cooldown = cooldown ?? CommitCooldown()
        self.id = cover.entityId
        self.cover = cover
        self.controller = controller
    }

    // MARK: - Actions

    func setPosition(to position: Int) {
        guard cover.isAvailable else { return }
        actionTask?.cancel()
        pendingPosition = position
        cooldown.commit()
        actionTask = Task {
            await controller.setPosition(of: id, to: position)
        }
    }

    func iconTapped() {
        guard cover.isAvailable else { return }
        switch state {
        case .open:
            if let position, position != 100 {
                performWithToggleFallback(`open`, ifSupported: .open)
            } else {
                performWithToggleFallback(close, ifSupported: .close)
            }
        case .closed:
            performWithToggleFallback(`open`, ifSupported: .open)
        case .opening:
            performWithToggleFallback(stop, ifSupported: .stop)
        case .closing:
            performWithToggleFallback(stop, ifSupported: .stop)
        case .unknown, .unavailable:
            break
        }
    }

    private func performWithToggleFallback(_ action: () -> Void, ifSupported feature: CoverEntity.Features) {
        if cover.supportedFeatures.contains(feature) {
            action()
        } else {
            toggle()
        }
    }

    func open() {
        guard cover.isAvailable else { return }
        actionTask?.cancel()
        actionTask = Task {
            await controller.openCover(id)
        }
    }

    func close() {
        guard cover.isAvailable else { return }
        actionTask?.cancel()
        actionTask = Task {
            await controller.closeCover(id)
        }
    }

    func stop() {
        guard cover.isAvailable else { return }
        actionTask?.cancel()
        actionTask = Task {
            await controller.stopCover(id)
        }
    }

    private func toggle() {
        actionTask?.cancel()
        actionTask = Task {
            await controller.toggleCover(id)
        }
    }
}

fileprivate extension CoverEntity.DeviceClass {

    func symbolName(for state: CoverEntity.State) -> String {
        switch state {
        case .open:
            return symbolPair.open
        case .closed:
            return symbolPair.closed
        case .opening, .closing:
            return "stop.fill"
        case .unknown:
            return "questionmark.circle"
        case .unavailable:
            return "exclamationmark.circle"
        }
    }
}

private extension CoverCardViewModel {
    enum Localization {
        static let open = String(localized: "Open", comment: "Cover entity state shown on card when the cover (blind/shutter/curtain) is open")
        static let closed = String(localized: "Closed", comment: "Cover entity state shown on card when the cover is closed")
        static let opening = String(localized: "Opening", comment: "Cover entity state shown on card while the cover is actively opening")
        static let closing = String(localized: "Closing", comment: "Cover entity state shown on card while the cover is actively closing")
        static let unknown = String(localized: "Unknown", comment: "Cover entity state shown on card when the state cannot be determined")
        static let unavailable = String(localized: "Unavailable", comment: "Cover entity state shown on card when the device is unreachable")

        static func positionAndState(_ position: Int, _ state: String) -> String {
            String(localized: "\(position)% \(state)", comment: "Cover card subtitle showing position percentage and state, e.g. '75% Open'")
        }

        static func transitioning(_ state: String) -> String {
            String(localized: "\(state)...", comment: "Cover card subtitle showing transitioning state with ellipsis, e.g. 'Opening...'")
        }
    }
}

// MARK: - Factory Registration

extension CoverCardViewModel {
    static func registration(controller: CoverControlling) -> ViewModelFactory.Registration {
        ViewModelFactory.Registration(
            makeViewModelsForArea: { area in
                area.covers.sorted(by: { $0.entityId < $1.entityId }).map {
                    CoverCardViewModel(cover: $0, controller: controller)
                }
            },
            makeViewModelForEntityId: { entityId, context in
                guard let cover = CoverEntity.fetch(byId: entityId, in: context) else { return nil }
                return CoverCardViewModel(cover: cover, controller: controller)
            }
        )
    }
}

// MARK: - EntityCardViewModel

extension CoverCardViewModel: EntityCardViewModel {
    func makeCardView() -> AnyView {
        AnyView(CoverCard(viewModel: self))
    }

    func makeOverlayView(isPresented: Binding<Bool>) -> AnyView? {
        AnyView(CoverControlPanel(viewModel: self, isPresented: isPresented))
    }
}
