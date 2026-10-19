import XCTest

extension XCUIApplication {

    static func screenshotApp() -> XCUIApplication {
        let app = XCUIApplication()
        /**
         Pin locale and region so promo screenshots don't inherit the capture machine's settings.
         Without this, a comma-decimal host produces "22,0°C" in screenshots for the English listing.
        */
        app.launchArguments += ["-screenshotMode", "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
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
