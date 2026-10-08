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
        XCTAssertTrue(start.appears())
        snap(app, "workout-tab")

        start.tap()
        app.buttons["workout.addExercise"].tap()
        XCTAssertTrue(app.buttons["exercisePicker.cancel"].appears())
        snap(app, "exercise-picker")
        app.buttons["exercisePicker.new"].tap()
        XCTAssertTrue(app.textFields["newExercise.name"].appears())
        snap(app, "new-exercise")
        app.navigationBars.buttons["Add Exercise"].tap()
        XCTAssertTrue(app.buttons["exercisePicker.cancel"].appears())
        app.pickExercise("Dumbbell Bench Press")
        let reps = app.textFields["workout.exercise.0.set.0.reps"]
        XCTAssertTrue(reps.appears())
        app.type("10", into: "workout.exercise.0.set.0.reps")
        app.buttons["workout.exercise.0.addSet"].tap()
        let check = app.buttons["workout.exercise.0.set.0.check"]
        XCTAssertEqual(check.value as? String, "done")
        XCTAssertTrue(app.staticTexts["restTimer.remaining"].appears())
        snap(app, "workout-screen-rest-timer")

        app.buttons["workout.exercise.0.menu"].tap()
        app.buttons["workout.exercise.0.restTime"].tap()
        let defaultRest = app.buttons["Default (1:30)"]
        XCTAssertTrue(defaultRest.appears())
        snap(app, "exercise-rest-time-picker")
        defaultRest.tap()

        app.buttons["workout.finish"].tap()
        XCTAssertTrue(app.buttons["finish.save"].appears())
        snap(app, "finish-sheet")

        app.buttons["finish.save"].tap()
        XCTAssertTrue(app.staticTexts["summary.workoutNumber"].appears())
        snap(app, "summary")
    }

    /// The Settings tab with Export and Import.
    @MainActor
    func testSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.buttons["tabs.settings"].tap()
        XCTAssertTrue(app.buttons["settings.export"].waitForExistence(timeout: 5))
        snap(app, "settings")
        app.buttons["settings.defaultRest"].tap()
        XCTAssertTrue(app.buttons["1:30"].appears())
        snap(app, "settings-default-rest-picker")
    }

    /// A workout with one exercise of each kind, and the set-type menu open.
    @MainActor
    func testWorkoutWithEveryKind() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let start = app.buttons["workoutTab.startEmpty"]
        XCTAssertTrue(start.appears())
        start.tap()
        for (index, name) in ["Dumbbell Bench Press", "Pull-up", "Plank"].enumerated() {
            app.addExercise(name, as: index)
        }
        let plus = app.buttons["workout.exercise.1.set.0.addedWeightPlus"]
        app.reveal(plus, swiping: { $0.swipeUp() })
        plus.tap()
        let duration = app.textFields["workout.exercise.2.set.0.duration"]
        app.reveal(duration, swiping: { $0.swipeUp() })
        app.type("45", into: "workout.exercise.2.set.0.duration")
        let typeMenu = app.buttons["workout.exercise.0.set.0.typeMenu"]
        app.reveal(typeMenu, swiping: { $0.swipeDown() })
        typeMenu.tap()
        XCTAssertTrue(app.buttons["setMenu.type.warmUp"].appears())
        snap(app, "workout-every-kind-set-type-menu")
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
