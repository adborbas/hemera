import SwiftData
import Testing
@testable import Hemera

@MainActor
struct DemoVacuumControllingTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let vacuum = VacuumEntity(entityId: "vacuum.robot", name: "Robot", state: .docked)

    init() throws {
        container = try ModelContainer(
            for: VacuumEntity.self, AreaEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        context.insert(vacuum)
    }

    @Test
    func startPauseStop_driveTheDemoRobotsState() async {
        let demo = DemoController(context: context)

        await demo.startVacuum(vacuum.entityId)
        #expect(vacuum.state == .cleaning)
        await demo.pauseVacuum(vacuum.entityId)
        #expect(vacuum.state == .paused)
        await demo.stopVacuum(vacuum.entityId)
        #expect(vacuum.state == .idle)
    }

    @Test
    func returnToBase_isReturning_thenDocks() async {
        let demo = DemoController(context: context)
        demo.vacuumDockingDelay = .milliseconds(5)

        await demo.returnVacuumToBase(vacuum.entityId)
        #expect(vacuum.state == .returning)

        await demo.vacuumDockingTasks[vacuum.entityId]?.value
        #expect(vacuum.state == .docked)
    }

    // The card cancels its last action on each tap, so Locate mid-return must not strand the robot.
    @Test
    func returnToBase_thenLocateFromTheCard_stillDocks() async {
        let demo = DemoController(context: context)
        demo.vacuumDockingDelay = .milliseconds(5)
        vacuum.supportedFeatures = [.returnHome, .locate]
        vacuum.state = .cleaning
        let card = VacuumCardViewModel(vacuum: vacuum, controller: demo)

        card.perform(.returnToBase)
        await card.actionTask?.value
        card.perform(.locate)
        await card.actionTask?.value

        await demo.vacuumDockingTasks[vacuum.entityId]?.value
        #expect(vacuum.state == .docked)
    }

    @Test
    func returnToBase_stoppedBeforeArriving_staysIdle() async {
        let demo = DemoController(context: context)
        demo.vacuumDockingDelay = .milliseconds(5)

        await demo.returnVacuumToBase(vacuum.entityId)
        await demo.stopVacuum(vacuum.entityId)

        await demo.vacuumDockingTasks[vacuum.entityId]?.value
        #expect(vacuum.state == .idle)
    }
}
