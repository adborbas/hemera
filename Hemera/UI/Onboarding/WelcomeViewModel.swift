import SwiftData
import SwiftUI

/** Real Hemera cards on an in-memory copy of the demo data, changing on their own. */
@Observable
@MainActor
final class WelcomeViewModel {

    struct Tile: Identifiable {
        let card: any EntityCardViewModel
        let isMedium: Bool
        var id: String { card.id }
    }

    // MARK: - Properties

    let tiles: [Tile]
    private(set) var isLeaving = false

    private static let changeInterval: Duration = .seconds(3)
    private static let pauseAfterTap: Duration = .seconds(5)
    private static let exitDuration: Duration = .seconds(0.35)
    private static let lightLow = Int(0.1 * 255)
    private static let lightHigh = Int(0.6 * 255)
    private static let coverClosed = 23
    private static let coverOpen = 77

    /** One store for the process: a tapped card's demo action can land after the screen has gone. */
    private static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: AppEnvironment.createSchema(),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        DemoDataProvider.seedDemoData(into: container.mainContext)
        prepareForWelcome(container.mainContext)
        return container
    }()

    private let sleep: @MainActor (Duration) async throws -> Void
    private let now: () -> ContinuousClock.Instant
    private let pickTile: ([Int]) -> Int?
    private var lastChanged: Int?
    private var pausedUntil: ContinuousClock.Instant?

    // MARK: - Init

    init(
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> ContinuousClock.Instant = { .now },
        pickTile: @escaping ([Int]) -> Int? = { $0.randomElement() }
    ) {
        let context = Self.container.mainContext
        let controller = DemoController(context: context)
        let factory = ViewModelFactory(context: context, container: Self.container)
        factory.registerAllDomains(
            lightController: controller, coverController: controller, sceneController: controller,
            scriptController: controller, switchController: controller, buttonController: controller,
            automationController: controller, climateController: controller, vacuumController: controller
        )
        let layout = [
            ("cover.kitchen_roller_shutter", true), ("light.office_desk", true),
            ("climate.living_room_ac", false), ("switch.kitchen_coffee_machine", false),
            ("scene.morning", false), ("vacuum.robot_vacuum", false),
        ]
        self.tiles = layout.compactMap { id, isMedium in
            factory.makeViewModel(forEntityId: id).map { Tile(card: $0, isMedium: isMedium) }
        }
        self.sleep = sleep
        self.now = now
        self.pickTile = pickTile
    }

    // MARK: - Public Methods

    /** Changes one random tile every few seconds until cancelled or leaving. */
    func run() async {
        isLeaving = false
        var wait = Self.changeInterval
        while true {
            do { try await sleep(wait) } catch { return }
            guard !isLeaving else { return }
            if let pausedUntil, now() < pausedUntil {
                wait = now().duration(to: pausedUntil)
                continue
            }
            changeNextTile()
            wait = Self.changeInterval
        }
    }

    func tap(_ tile: Tile) {
        pausedUntil = now().advanced(by: Self.pauseAfterTap)
        Self.performTapAction(of: tile.card)
    }

    /** Plays the exit, then calls `proceed`. */
    func getStarted(then proceed: @escaping @MainActor () -> Void) {
        guard !isLeaving else { return }
        isLeaving = true
        Task {
            try? await sleep(Self.exitDuration)
            proceed()
        }
    }
}

// MARK: - Private Methods

private extension WelcomeViewModel {

    func changeNextTile() {
        guard let index = pickTile(tiles.indices.filter { $0 != lastChanged }) else { return }
        lastChanged = index
        nudge(tiles[index].card)
    }

    /** One visible change: a light dims or brightens, a cover moves, the others act as when tapped. */
    func nudge(_ card: any EntityCardViewModel) {
        let id = card.id
        let context = Self.container.mainContext
        if let light = LightEntity.fetch(byId: id, in: context) {
            if light.state != .on {
                light.state = .on
                light.brightness = Self.lightLow
            } else {
                light.brightness = (light.brightness ?? 0) >= Self.lightHigh ? Self.lightLow : Self.lightHigh
            }
        } else if let cover = CoverEntity.fetch(byId: id, in: context) {
            cover.state = .open
            cover.currentPosition = (cover.currentPosition ?? 0) >= Self.coverOpen ? Self.coverClosed : Self.coverOpen
        } else if let vacuum = VacuumEntity.fetch(byId: id, in: context) {
            vacuum.state = vacuum.state == .cleaning ? .docked : .cleaning
        } else {
            Self.performTapAction(of: card)
        }
    }

    static func performTapAction(of card: any EntityCardViewModel) {
        switch card {
        case let light as LightCardViewModel: light.toggle()
        case let cover as CoverCardViewModel: cover.iconTapped()
        case let vacuum as VacuumCardViewModel: vacuum.iconTapped()
        case let outlet as SwitchCardViewModel: outlet.toggle()
        case let climate as ClimateCardViewModel: climate.togglePower()
        case let scene as SceneCardViewModel: scene.activate()
        default: break
        }
    }

    /** Short names, no temperature reading, and lively starting states, so every card fits and moves. */
    static func prepareForWelcome(_ context: ModelContext) {
        let blinds = CoverEntity.fetch(byId: "cover.kitchen_roller_shutter", in: context)
        blinds?.name = "Kitchen Blinds"
        blinds?.state = .open
        blinds?.currentPosition = coverClosed
        let lamp = LightEntity.fetch(byId: "light.office_desk", in: context)
        lamp?.state = .on
        lamp?.brightness = lightHigh
        ClimateEntity.fetch(byId: "climate.living_room_ac", in: context)?.currentTemperature = nil
        SwitchEntity.fetch(byId: "switch.kitchen_coffee_machine", in: context)?.name = "Coffee"
        SceneEntity.fetch(byId: "scene.morning", in: context)?.name = "Morning"
        let vacuum = VacuumEntity.fetch(byId: "vacuum.robot_vacuum", in: context)
        vacuum?.name = "Vacuum"
        vacuum?.state = .cleaning
    }
}
