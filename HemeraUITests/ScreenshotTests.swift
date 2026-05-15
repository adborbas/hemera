import XCTest

final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.screenshotApp()
        app.launch()

        // Wait for the dashboard to appear
        let homeTab = app.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
    }

    // MARK: - Home Tab

    func testScreenshot_01_HomeTab_Portrait() throws {
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        takeScreenshot(named: "01_Home_Portrait")
    }

    func testScreenshot_01_HomeTab_Landscape() throws {
        try skipUnlessIPad()
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)
        takeScreenshot(named: "01_Home_Landscape")
    }

    // MARK: - Areas Tab

    func testScreenshot_02_AreasTab_Portrait() throws {
        XCUIDevice.shared.orientation = .portrait
        app.buttons["Areas"].firstMatch.tap()
        sleep(1)
        takeScreenshot(named: "02_Areas_Portrait")
    }

    func testScreenshot_02_AreasTab_Landscape() throws {
        try skipUnlessIPad()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["Areas"].firstMatch.tap()
        sleep(1)
        takeScreenshot(named: "02_Areas_Landscape")
    }

    // MARK: - Light Control Panel

    func testScreenshot_03_LightControlPanel_Portrait() throws {
        XCUIDevice.shared.orientation = .portrait
        let ceilingLight = app.staticTexts["light.living_room_ceiling"].firstMatch
        XCTAssertTrue(ceilingLight.waitForExistence(timeout: 5))
        ceilingLight.tap()
        sleep(1)
        takeScreenshot(named: "03_LightControl_Portrait")
    }

    func testScreenshot_03_LightControlPanel_Landscape() throws {
        try skipUnlessIPad()
        XCUIDevice.shared.orientation = .landscapeLeft
        let ceilingLight = app.staticTexts["light.living_room_ceiling"].firstMatch
        XCTAssertTrue(ceilingLight.waitForExistence(timeout: 5))
        ceilingLight.tap()
        sleep(1)
        takeScreenshot(named: "03_LightControl_Landscape")
    }

    // MARK: - Cover Control Panel

    func testScreenshot_04_CoverControlPanel_Portrait() throws {
        XCUIDevice.shared.orientation = .portrait
        let blinds = app.staticTexts["cover.living_room_blinds"].firstMatch
        XCTAssertTrue(blinds.waitForExistence(timeout: 5))
        blinds.tap()
        sleep(1)
        takeScreenshot(named: "04_CoverControl_Portrait")
    }

    func testScreenshot_04_CoverControlPanel_Landscape() throws {
        try skipUnlessIPad()
        XCUIDevice.shared.orientation = .landscapeLeft
        let blinds = app.staticTexts["cover.living_room_blinds"].firstMatch
        XCTAssertTrue(blinds.waitForExistence(timeout: 5))
        blinds.tap()
        sleep(1)
        takeScreenshot(named: "04_CoverControl_Landscape")
    }

    // MARK: - Switch Control Panel

    func testScreenshot_05_SwitchControlPanel_Portrait() throws {
        XCUIDevice.shared.orientation = .portrait
        navigateToAreasTab()
        let kitchen = app.staticTexts["Kitchen"].firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 5))
        kitchen.tap()
        let coffeeMachine = app.staticTexts["switch.kitchen_coffee_machine"].firstMatch
        XCTAssertTrue(coffeeMachine.waitForExistence(timeout: 5))
        coffeeMachine.tap()
        sleep(1)
        takeScreenshot(named: "05_SwitchControl_Portrait")
    }

    func testScreenshot_05_SwitchControlPanel_Landscape() throws {
        try skipUnlessIPad()
        XCUIDevice.shared.orientation = .landscapeLeft
        navigateToAreasTab()
        let kitchen = app.staticTexts["Kitchen"].firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 5))
        kitchen.tap()
        let coffeeMachine = app.staticTexts["switch.kitchen_coffee_machine"].firstMatch
        XCTAssertTrue(coffeeMachine.waitForExistence(timeout: 5))
        coffeeMachine.tap()
        sleep(1)
        takeScreenshot(named: "05_SwitchControl_Landscape")
    }

    // MARK: - Area Detail (Living Room)

    func testScreenshot_07_AreaDetail_Portrait() throws {
        XCUIDevice.shared.orientation = .portrait
        navigateToAreasTab()
        let livingRoom = app.staticTexts["Living Room"].firstMatch
        XCTAssertTrue(livingRoom.waitForExistence(timeout: 5))
        livingRoom.tap()
        sleep(1)
        takeScreenshot(named: "07_AreaDetail_Portrait")
    }

    func testScreenshot_07_AreaDetail_Landscape() throws {
        try skipUnlessIPad()
        XCUIDevice.shared.orientation = .landscapeLeft
        navigateToAreasTab()
        let livingRoom = app.staticTexts["Living Room"].firstMatch
        XCTAssertTrue(livingRoom.waitForExistence(timeout: 5))
        livingRoom.tap()
        sleep(1)
        takeScreenshot(named: "07_AreaDetail_Landscape")
    }

    // MARK: - Climate Control Panel

    func testScreenshot_06_ClimateControlPanel_Portrait() throws {
        XCUIDevice.shared.orientation = .portrait
        let ac = app.staticTexts["climate.living_room_ac"].firstMatch
        XCTAssertTrue(ac.waitForExistence(timeout: 5))
        tapCardLabel(ac)
        sleep(1)
        takeScreenshot(named: "06_ClimateControl_Portrait")
    }

    func testScreenshot_06_ClimateControlPanel_Landscape() throws {
        try skipUnlessIPad()
        XCUIDevice.shared.orientation = .landscapeLeft
        let ac = app.staticTexts["climate.living_room_ac"].firstMatch
        XCTAssertTrue(ac.waitForExistence(timeout: 5))
        tapCardLabel(ac)
        sleep(1)
        takeScreenshot(named: "06_ClimateControl_Landscape")
    }
}

// MARK: - Helpers

private extension ScreenshotTests {
    /// Taps to the right of a card label text to ensure the tap lands on
    /// the label area rather than the adjacent card icon. Short labels like
    /// "AC" can have their center too close to the icon on wider iPad layouts.
    func tapCardLabel(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 3.0, dy: 0.5)).tap()
    }

    func navigateToAreasTab() {
        let areasButton = app.buttons["Areas"].firstMatch
        let areasNav = app.navigationBars["Areas"]

        areasButton.tap()

        if !areasNav.waitForExistence(timeout: 3) {
            areasButton.tap()
        }

        XCTAssertTrue(areasNav.waitForExistence(timeout: 5))
    }

    func skipUnlessIPad() throws {
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "Landscape screenshots are only captured on iPad"
        )
    }
}
