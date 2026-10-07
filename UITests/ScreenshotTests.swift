import XCTest

/// Run by `just screenshot` in light, dark and accessibility-large modes.
/// Each screen becomes a kept attachment named after the screen.
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["placeholder"].waitForExistence(timeout: 5))
        snap(app, "launch")
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
