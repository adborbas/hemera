import XCTest

extension XCUIApplication {

    static func screenshotApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-screenshotMode"]
        return app
    }
}

extension XCTestCase {

    func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
