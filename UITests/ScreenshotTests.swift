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
        snap(app, "exercise-picker")
        app.buttons["exercisePicker.new"].tap()
        XCTAssertTrue(app.textFields["newExercise.name"].waitForExistence(timeout: 5))
        snap(app, "new-exercise")
        app.navigationBars.buttons["Add Exercise"].tap()
        XCTAssertTrue(app.buttons["exercisePicker.cancel"].waitForExistence(timeout: 5))
        app.pickExercise("Dumbbell Bench Press")
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

    /// A workout with one exercise of each kind, and the set-type menu open.
    @MainActor
    func testWorkoutWithEveryKind() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let start = app.buttons["workoutTab.startEmpty"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        for (index, name) in ["Dumbbell Bench Press", "Pull-up", "Plank"].enumerated() {
            // At the largest text size the button sits below the fold of the lazy list.
            reveal(app.buttons["workout.addExercise"], in: app, swiping: { $0.swipeUp() })
            app.buttons["workout.addExercise"].tap()
            XCTAssertTrue(app.buttons["exercisePicker.cancel"].waitForExistence(timeout: 5))
            app.pickExercise(name)
            let header = app.staticTexts["workout.exercise.\(index).name"]
            XCTAssertTrue(header.waitForExistence(timeout: 5))
        }
        let plus = app.buttons["workout.exercise.1.set.0.addedWeightPlus"]
        reveal(plus, in: app, swiping: { $0.swipeUp() })
        plus.tap()
        let duration = app.textFields["workout.exercise.2.set.0.duration"]
        reveal(duration, in: app, swiping: { $0.swipeUp() })
        app.focus(duration)
        duration.typeText("45")
        app.buttons["keyboard.done"].tap()
        let typeMenu = app.buttons["workout.exercise.0.set.0.typeMenu"]
        reveal(typeMenu, in: app, swiping: { $0.swipeDown() })
        typeMenu.tap()
        XCTAssertTrue(app.buttons["setMenu.type.warmUp"].waitForExistence(timeout: 5))
        snap(app, "workout-every-kind-set-type-menu")
    }

    /// Swipes until the element of the lazy list is hittable.
    @MainActor
    private func reveal(
        _ element: XCUIElement, in app: XCUIApplication, swiping swipe: (XCUIApplication) -> Void
    ) {
        for _ in 0..<15 where !element.isHittable {
            swipe(app)
        }
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
