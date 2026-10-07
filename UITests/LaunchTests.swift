import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testWorkoutTabAppears() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["workoutTab.startEmpty"].waitForExistence(timeout: 5))
    }
}
