import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testPlaceholderAppears() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["placeholder"].waitForExistence(timeout: 5))
    }
}
