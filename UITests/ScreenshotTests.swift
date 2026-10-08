import XCTest

/// Run by `just screenshot` in light, dark and accessibility-large modes.
/// Each screen becomes a kept attachment named after the screen.
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let start = app.buttons["workoutTab.startEmpty"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        snap(app, "workout-tab")

        start.tap()
        app.buttons["workout.addExercise"].tap()
        XCTAssertTrue(app.buttons["exercisePicker.cancel"].waitForExistence(timeout: 5))
        // The list is lazy: rows below the fold exist only once scrolled to.
        let row = app.buttons["exercisePicker.row.Dumbbell Bench Press"]
        for _ in 0..<15 where !row.isHittable {
            app.swipeUp()
        }
        row.tap()
        let reps = app.textFields["workout.exercise.0.set.0.reps"]
        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        app.focus(reps)
        reps.typeText("10")
        app.buttons["keyboard.done"].tap()
        app.buttons["workout.exercise.0.addSet"].tap()
        let check = app.buttons["workout.exercise.0.set.0.check"]
        check.tap()
        XCTAssertEqual(check.value as? String, "done")
        // ponytail: fixed wait for the check-off tint and bounce (under half a second) to settle.
        Thread.sleep(forTimeInterval: 1)
        snap(app, "workout-screen")

        app.buttons["workout.finish"].tap()
        XCTAssertTrue(app.buttons["finish.save"].waitForExistence(timeout: 5))
        snap(app, "finish-sheet")

        app.buttons["finish.save"].tap()
        XCTAssertTrue(app.staticTexts["summary.workoutNumber"].waitForExistence(timeout: 5))
        snap(app, "summary")
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
