import XCTest

extension XCUIApplication {

    static func screenshotApp() -> XCUIApplication {
        let app = XCUIApplication()
        /**
         Pin locale and region so promo screenshots don't inherit the capture machine's settings.
         Without this, a comma-decimal host produces "22,0°C" in screenshots for the English listing.
        */
        app.launchArguments += ["-screenshotMode", "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        // xcodebuild passes TEST_RUNNER_SCREENSHOT_THEME* from capture-screenshots.sh as these.
        let environment = ProcessInfo.processInfo.environment
        if let theme = environment["SCREENSHOT_THEME"] {
            app.launchArguments += ["-screenshotTheme", theme]
        }
        if let intensity = environment["SCREENSHOT_THEME_INTENSITY"] {
            app.launchArguments += ["-screenshotThemeIntensity", intensity]
        }
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
