import XCTest

/// Walks the Release app against the throwaway Home Assistant that `scripts/smoke-test.sh` starts.
final class SmokeTests: XCTestCase {

    private static var loggedIn = false

    private let timeout: TimeInterval = 60

    // Mirrors the areas and entity area_ids in scripts/smoke/homeassistant.
    private let seededAreas: [(id: String, name: String, entityIds: Set<String>)] = [
        // The thermostat has no area of its own, only its device does.
        ("smoke_bedroom", "Smoke Bedroom", ["climate.smoke_thermostat"]),
        ("smoke_kitchen", "Smoke Kitchen", [
            "automation.smoke_schedule", "button.smoke_doorbell", "scene.smoke_evening", "script.smoke_routine",
            "switch.smoke_kettle",
        ]),
        ("smoke_living_room", "Smoke Living Room", [
            "binary_sensor.smoke_door", "cover.smoke_blind", "light.smoke_lamp", "sensor.smoke_humidity",
            "sensor.smoke_temperature", "switch.smoke_fan",
        ]),
    ]
    // The Suggested Home of that fixture: the template lamp and switches start unknown, so they are left out.
    private let suggestedHome: Set<String> = [
        "button.smoke_doorbell", "climate.smoke_thermostat", "cover.smoke_blind", "scene.smoke_evening",
        "script.smoke_routine",
    ]

    override func setUp() {
        continueAfterFailure = false
    }

    func testSmoke_01_Login() throws {
        let app = launchedApp()
        tap(app.buttons["welcomeGetStarted"])
        tap(app.buttons["serverEnterManually"])

        let address = app.textFields["serverAddressField"]
        tap(address)
        address.typeText(try environment("SMOKE_HA_URL"))
        tap(app.buttons["onboardingBottomButton"])
        // A SwiftUI alert action exposes its identifier twice, on a nested pair of buttons.
        tap(app.alerts.buttons["httpWarningContinue"].firstMatch)

        // The sign-in page belongs to Home Assistant, so its fields have no identifiers of ours.
        let username = app.webViews.textFields.firstMatch
        tap(username)
        username.typeText(try environment("SMOKE_USERNAME"))
        let password = app.webViews.secureTextFields.firstMatch
        tap(password)
        password.typeText(try environment("SMOKE_PASSWORD") + "\n")

        // Login opens the Home step, filled with the Suggested Home.
        let homeStep = app.descendants(matching: .any)["onboardingHomeStep"]
        XCTAssertTrue(homeStep.waitForExistence(timeout: timeout), "No Home step:\n\(app.debugDescription)")
        for entityId in suggestedHome {
            XCTAssertTrue(homeStep.descendants(matching: .any)[entityId].waitForExistence(timeout: timeout),
                          "The Home step never showed \(entityId):\n\(app.debugDescription)")
        }
        XCTAssertEqual(seededEntityIds(in: app), suggestedHome, "Wrong Suggested Home in the Home step")
        let bottomButton = app.buttons["onboardingBottomButton"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: bottomButton)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: timeout), .completed, "Continue never enabled")
        tap(bottomButton)

        // Continue opens the Theme step; Finish keeps the theme as it is and opens the app.
        let themeStep = app.descendants(matching: .any)["onboardingThemeStep"]
        XCTAssertTrue(themeStep.waitForExistence(timeout: timeout), "No Theme step:\n\(app.debugDescription)")
        tap(bottomButton)
        let left = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: themeStep)
        XCTAssertEqual(XCTWaiter().wait(for: [left], timeout: timeout), .completed, "Finish never left onboarding")

        // Home shows the tiles the step left. The regular-width pager also holds the Areas page's cards.
        for entityId in suggestedHome {
            XCTAssertTrue(app.descendants(matching: .any)[entityId].waitForExistence(timeout: timeout),
                          "Home never showed \(entityId):\n\(app.debugDescription)")
        }
        XCTAssertEqual(seededEntityIds(in: app).filter { !$0.hasPrefix("area.") }, suggestedHome,
                       "Wrong Suggested Home")

        assertOnAreasAfterSync(app)
        Self.loggedIn = true
    }

    func testSmoke_02_RelaunchStaysLoggedIn() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to relaunch with")
        let app = launchedApp()

        // A lost session lands on the welcome screen, where this grid cannot exist.
        assertOnAreasAfterSync(app)
    }

    func testSmoke_03_Areas() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to read areas with")
        let app = launchedApp()
        assertOnAreasAfterSync(app)

        for area in seededAreas {
            let card = app.buttons["area.\(area.id)"]
            XCTAssertTrue(card.waitForExistence(timeout: timeout), "No \(area.name) card:\n\(app.debugDescription)")
            XCTAssertEqual(card.label, area.name)
            card.tap()
            for entityId in area.entityIds {
                XCTAssertTrue(app.descendants(matching: .any)[entityId].waitForExistence(timeout: timeout),
                              "\(area.name) never showed \(entityId):\n\(app.debugDescription)")
            }
            XCTAssertEqual(seededEntityIds(in: app), area.entityIds, "Wrong entities in \(area.name)")
            tap(app.buttons["screenBack"])
        }
    }

    func testSmoke_04_Scene() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to activate a scene with")
        let before = try blocking { try await self.serverState(of: "scene.smoke_evening") }
        let app = openedArea("smoke_kitchen")

        // A scene has no overlay, so tapping its card activates it.
        tap(app.staticTexts["scene.smoke_evening"])
        // A scene's state is the time it was last activated.
        try blocking {
            try await self.waitForServer("scene.smoke_evening", "a new activation time") { $0.state != before.state }
        }
    }

    func testSmoke_05_Script() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to run a script with")
        let before = try blocking { try await self.serverState(of: "script.smoke_routine") }
        let app = openedArea("smoke_kitchen")

        // A script has no overlay, so tapping its card runs it.
        tap(app.staticTexts["script.smoke_routine"])
        try blocking {
            try await self.waitForServer("script.smoke_routine", "a new last_triggered") {
                $0.lastTriggered != nil && $0.lastTriggered != before.lastTriggered
            }
        }
    }

    func testSmoke_06_Sensors() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to read sensors with")
        let app = openedArea("smoke_living_room")

        // Both are seeded in scripts/smoke/homeassistant/configuration.yaml.
        assertLabel(of: app.buttons["sensor.smoke_temperature"], is: "21.5°C")
        assertLabel(of: app.staticTexts["binary_sensor.smoke_door.state"], is: "Open")
    }

    func testSmoke_07_LiveUpdate() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to receive updates with")
        let app = openedArea("smoke_kitchen")
        let kettle = app.staticTexts["switch.smoke_kettle.state"]
        assertLabel(of: kettle, is: "Off")

        try blocking { try await self.callService("switch", "turn_on", on: "switch.smoke_kettle") }
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'On'"), object: kettle)
        XCTAssertEqual(XCTWaiter().wait(for: [shown], timeout: timeout), .completed, "The kettle never showed On")
    }

    // The newest means are seeded by scripts/smoke/homeassistant/custom_components/smoke.
    func testSmoke_08_TemperatureHistory() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to read history with")
        assertHistory(of: "sensor.smoke_temperature", newest: ["day": "21.5", "week": "21.0", "month": "21.0"])
    }

    func testSmoke_09_HumidityHistory() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to read history with")
        assertHistory(of: "sensor.smoke_humidity", newest: ["day": "48.0", "week": "47.5", "month": "47.5"])
    }

    // Template lights and switches start unknown, so the app's toggle turns them on.
    func testSmoke_10_Light() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to switch a light with")
        try assertIconTap("light.smoke_lamp", in: "smoke_living_room", turns: "unknown", into: "on")
    }

    func testSmoke_11_Switch() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to flip a switch with")
        try assertIconTap("switch.smoke_fan", in: "smoke_living_room", turns: "unknown", into: "on")
    }

    func testSmoke_12_Cover() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to open a cover with")
        try assertIconTap("cover.smoke_blind", in: "smoke_living_room", turns: "closed", into: "open")
    }

    func testSmoke_13_Climate() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to turn off a thermostat with")
        try assertIconTap("climate.smoke_thermostat", in: "smoke_bedroom", turns: "heat", into: "off")
    }

    func testSmoke_14_Automation() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to disable an automation with")
        try assertIconTap("automation.smoke_schedule", in: "smoke_kitchen", turns: "on", into: "off")
    }

    func testSmoke_15_Button() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to press a button with")
        let before = try blocking { try await self.serverState(of: "button.smoke_doorbell") }
        let app = openedArea("smoke_kitchen")

        tapIcon(of: "button.smoke_doorbell", in: app)
        // A restart button asks first. Its action exposes the identifier twice, like every alert action.
        tap(app.alerts.buttons["button.smoke_doorbell.confirm"].firstMatch)
        // A button's state is the time it was last pressed.
        try blocking {
            try await self.waitForServer("button.smoke_doorbell", "a new press time") { $0.state != before.state }
        }
    }

    func testSmoke_16_Settings() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to open Settings with")
        let url = try environment("SMOKE_HA_URL")
        let app = openedSettings()

        tap(app.buttons["settingsKioskMode"])
        let kiosk = app.switches["kioskModeToggle"]
        XCTAssertTrue(kiosk.waitForExistence(timeout: timeout), "Kiosk Mode never opened")
        XCTAssertEqual(kiosk.value as? String, "0", "Kiosk Mode is on in a fresh install")
        tap(app.buttons["screenBack"])

        tap(app.buttons["settingsAcknowledgements"])
        XCTAssertTrue(app.collectionViews["acknowledgements"].waitForExistence(timeout: timeout),
                      "Acknowledgements never opened")
        tap(app.buttons["screenBack"])

        tap(app.buttons["settingsAccount"])
        let serverURL = app.buttons["settingsServerURL"]
        assertShows(serverURL, url)
        assertShows(app.staticTexts["settingsHAVersion"], try environment("SMOKE_HA_VERSION"))

        tap(serverURL)
        let address = app.textFields["serverAddressField"]
        XCTAssertTrue(address.waitForExistence(timeout: timeout), "Server URL never opened")
        XCTAssertEqual(address.value as? String, url)
        tap(app.buttons["screenBack"])

        // Back on Account with the address it started with.
        assertShows(serverURL, url)
    }

    func testSmoke_17_OpenServer() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to open the server with")
        let app = openedSettings()
        tap(app.buttons["settingsAccount"])
        tap(app.buttons["settingsOpenServer"])

        // Only a frontend that authenticated and fetched the server's areas can name one.
        let area = app.webViews.buttons["Smoke Kitchen"]
        XCTAssertTrue(area.waitForExistence(timeout: timeout), "The frontend never loaded:\n\(app.debugDescription)")
        tap(app.buttons["serverWebViewDone"])
        XCTAssertTrue(app.buttons["settingsOpenServer"].waitForExistence(timeout: timeout), "Open Server never closed")
    }

    func testSmoke_18_HideAndShow() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to hide an entity with")
        try XCTSkipUnless(try environment("SMOKE_ROLE") == "owner", "Hiding is an owner flow")
        let app = openedArea("smoke_kitchen")
        let script = app.staticTexts["script.smoke_routine"]

        toggleHidden("script.smoke_routine", holding: script, in: app)
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: script)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: timeout), .completed, "The hidden script still shows")

        toggleHidden("script.smoke_routine", holding: app.staticTexts["switch.smoke_kettle"], in: app)
        XCTAssertTrue(script.waitForExistence(timeout: timeout), "The shown script never came back")
    }

    func testSmoke_19_AddToHome() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to add to Home with")
        try XCTSkipUnless(try environment("SMOKE_ROLE") == "owner", "Adding to Home is an owner flow")
        let app = openedArea("smoke_kitchen")
        hold(app.staticTexts["switch.smoke_kettle"])
        tap(app.buttons["addToHome"])

        // The app opens on Home, so the kettle card there means Home kept it and the session.
        let relaunched = launchedApp()
        XCTAssertTrue(relaunched.staticTexts["switch.smoke_kettle"].waitForExistence(timeout: timeout),
                      "Home lost the kettle after a relaunch:\n\(relaunched.debugDescription)")
    }

    // Logging out ends the session, so this runs last.
    func testSmoke_20_Logout() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to log out of")
        let app = openedSettings()
        tap(app.buttons["settingsAccount"])
        tap(app.buttons["settingsLogOut"])
        tap(app.alerts.buttons["logOutConfirm"].firstMatch)
        XCTAssertTrue(app.buttons["welcomeGetStarted"].waitForExistence(timeout: timeout),
                      "Logout never reached the welcome screen:\n\(app.debugDescription)")
    }

    func testSmoke_21_PadPillNavigation() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to switch feeds with")
        try XCTSkipUnless(isPad, "Pills are the regular-width header")
        let app = launchedApp()
        let home = app.descendants(matching: .any)[homeTile].firstMatch
        let areas = app.scrollViews["areasGrid"]
        assertShowsFeed(home, in: app)
        XCTAssertTrue(areas.waitForExistence(timeout: timeout), "The Areas page was never built")
        XCTAssertFalse(areas.isHittable, "The Areas page is hittable off screen, so this step proves nothing")

        tap(app.buttons["pill.areas"])
        assertShowsFeed(areas, in: app)
        tap(app.buttons["pill.home"])
        assertShowsFeed(home, in: app)
    }

    func testSmoke_22_PadAccountOpensSettings() throws {
        try XCTSkipUnless(Self.loggedIn, "Login failed, so there is no session to open Settings with")
        try XCTSkipUnless(isPad, "The avatar opens the side menu in compact width")
        let app = launchedApp()
        tap(app.buttons["accountButton"])
        let account = app.buttons["settingsAccount"]
        XCTAssertTrue(account.waitForExistence(timeout: timeout), "Settings never opened:\n\(app.debugDescription)")

        tap(app.buttons["screenClose"])
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: account)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: timeout), .completed, "Settings never closed")
        assertShowsFeed(app.descendants(matching: .any)[homeTile].firstMatch, in: app)
    }

    // MARK: - Helpers

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    // Areas shows area cards, never entity tiles, so this tile is on Home only.
    private let homeTile = "cover.smoke_blind"

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()
        return app
    }

    private func openedArea(_ id: String) -> XCUIApplication {
        let app = launchedApp()
        assertOnAreasAfterSync(app)
        tap(app.buttons["area.\(id)"])
        return app
    }

    private func openedSettings() -> XCUIApplication {
        let app = launchedApp()
        tap(app.buttons["accountButton"])
        tap(app.buttons["drawerSettings"])
        return app
    }

    private func hold(_ card: XCUIElement) {
        XCTAssertTrue(card.waitForExistence(timeout: timeout), "\(card) never appeared")
        card.press(forDuration: 1)
    }

    private func toggleHidden(_ entityId: String, holding card: XCUIElement, in app: XCUIApplication) {
        hold(card)
        tap(app.buttons["showHideItems"])
        tap(app.buttons["\(entityId).hideToggle"])
        tap(app.buttons["hideModeDone"])
    }

    // The grid only exists once sync has stored something to show, unlike the empty and failed states.
    private func assertOnAreasAfterSync(_ app: XCUIApplication) {
        if isPad {
            tap(app.buttons["pill.areas"])
        } else {
            tap(app.buttons["accountButton"])
            tap(app.buttons["feed.areas"])
        }
        let grid = app.scrollViews["areasGrid"]
        XCTAssertTrue(grid.waitForExistence(timeout: timeout), "Areas grid never appeared:\n\(app.debugDescription)")
    }

    // The pager keeps neighbouring feeds alive off screen, so only hittability says which one shows.
    private func assertShowsFeed(_ content: XCUIElement, in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let onScreen = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: content)
        XCTAssertEqual(XCTWaiter().wait(for: [onScreen], timeout: timeout), .completed,
                       "\(content) is not the feed on screen:\n\(app.debugDescription)", file: file, line: line)
    }

    // Every seeded entity id contains "smoke_", and `<entity id>.state` belongs to the same entity.
    private func seededEntityIds(in app: XCUIApplication) -> Set<String> {
        let cards = app.descendants(matching: .any).matching(NSPredicate(format: "identifier CONTAINS '.smoke_'"))
        return Set(cards.allElementsBoundByIndex.map {
            $0.identifier.split(separator: ".").prefix(2).joined(separator: ".")
        })
    }

    // The empty and failed states draw no chart, so only a range that returned history passes.
    private func assertHistory(of sensorId: String, newest: [String: String]) {
        let app = openedArea("smoke_living_room")
        tap(app.buttons[sensorId])
        for range in ["day", "week", "month"] {
            let chip = app.buttons["climateRange.\(range)"]
            tap(chip)
            XCTAssertTrue(chip.isSelected, "\(range) was not selected")
            let loading = app.descendants(matching: .any)["climateHistoryLoading"]
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: loading)
            XCTAssertEqual(XCTWaiter().wait(for: [settled], timeout: timeout), .completed, "\(range) never loaded")
            XCTAssertTrue(app.descendants(matching: .any)["climateHistoryChart"].exists,
                          "\(sensorId) showed no \(range) chart:\n\(app.debugDescription)")
            // The hourly and 5-minute means differ, so this also shows which range's data is drawn.
            let readout = app.descendants(matching: .any)["climateHistoryReadout"].label
            XCTAssertTrue(readout.contains(newest[range]!), "\(range) readout was \(readout)")
        }
    }

    // Checking the start state keeps a tap that did nothing from passing on a state already there.
    private func assertIconTap(_ entityId: String, in area: String, turns from: String, into to: String) throws {
        let before = try blocking { try await self.serverState(of: entityId) }
        XCTAssertEqual(before.state, from, "\(entityId) did not start \(from)")
        let app = openedArea(area)
        tapIcon(of: entityId, in: app)
        try blocking { try await self.waitForServer(entityId, to) { $0.state == to } }
    }

    // Found under `buttons` only with the button trait, and VoiceOver needs a name for it.
    private func tapIcon(of entityId: String, in app: XCUIApplication) {
        let icon = app.buttons["\(entityId).icon"]
        XCTAssertTrue(icon.waitForExistence(timeout: timeout), "No \(entityId) icon:\n\(app.debugDescription)")
        XCTAssertFalse(icon.label.isEmpty, "\(entityId) icon has no label")
        icon.tap()
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) never appeared", file: file, line: line)
        element.tap()
    }

    // A labelled row reads as "Label, value" or splits the value out, depending on the row.
    private func assertShows(_ element: XCUIElement, _ expected: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) never appeared", file: file, line: line)
        let shown = "\(element.label) \(element.value as? String ?? "")"
        XCTAssertTrue(shown.contains(expected), "\(element) shows \(shown), not \(expected)", file: file, line: line)
    }

    private func assertLabel(of element: XCUIElement, is expected: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) never appeared", file: file, line: line)
        XCTAssertEqual(element.label, expected, file: file, line: line)
    }

    private func environment(_ name: String) throws -> String {
        try XCTUnwrap(ProcessInfo.processInfo.environment[name], "\(name) is set by scripts/smoke-test.sh")
    }
}

// MARK: - Home Assistant

private extension SmokeTests {
    struct EntityState: Decodable {
        struct Attributes: Decodable {
            let last_triggered: String?
        }

        let state: String
        let attributes: Attributes

        var lastTriggered: String? { attributes.last_triggered }
    }

    struct ServerError: Error, CustomStringConvertible {
        let description: String
    }

    // A failing async step restarts the test runner, which resets `loggedIn`, so steps stay synchronous.
    func blocking<T>(_ work: @escaping () async throws -> T) throws -> T {
        let done = expectation(description: "Home Assistant answered")
        var result: Result<T, Error>?
        Task {
            do { result = .success(try await work()) } catch { result = .failure(error) }
            done.fulfill()
        }
        wait(for: [done], timeout: timeout * 2)
        return try XCTUnwrap(result, "Home Assistant never answered").get()
    }

    func serverState(of entityId: String) async throws -> EntityState {
        try JSONDecoder().decode(EntityState.self, from: try await send("GET", "/api/states/\(entityId)"))
    }

    func callService(_ domain: String, _ service: String, on entityId: String) async throws {
        _ = try await send("POST", "/api/services/\(domain)/\(service)", body: ["entity_id": entityId])
    }

    // Polls, because the app's service call reaches the server some time after the tap.
    func waitForServer(_ entityId: String, _ expectation: String,
                       until isDone: (EntityState) -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var last = try await serverState(of: entityId)
        while !isDone(last) {
            guard Date() < deadline else {
                throw ServerError(description: "\(entityId) never showed \(expectation), last saw \(last)")
            }
            try await Task.sleep(for: .milliseconds(250))
            last = try await serverState(of: entityId)
        }
    }

    func send(_ method: String, _ path: String, body: [String: String]? = nil) async throws -> Data {
        var request = URLRequest(url: try XCTUnwrap(URL(string: try environment("SMOKE_HA_URL") + path)))
        request.httpMethod = method
        request.setValue("Bearer \(try environment("SMOKE_HA_TOKEN"))", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let body = String(decoding: data, as: UTF8.self)
            throw ServerError(description: "\(method) \(path) failed: \(response), \(body)")
        }
        return data
    }
}
