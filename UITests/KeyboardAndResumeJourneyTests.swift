import XCTest

/// Journey 4: the keyboard toolbar, minimizing and resuming a workout, and discarding it.
final class KeyboardAndResumeJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testKeyboardMinimizeResumeAndDiscard() {
        let app = XCUIApplication.launchedForTesting()
        let firstReps = app.textFields["workout.exercise.0.set.0.reps"]

        step("Start a workout with two sets of Dumbbell Bench Press") {
            app.startWorkout()
            app.addExercise("Dumbbell Bench Press", as: 0)
            app.buttons["workout.exercise.0.addSet"].tap()
        }

        step("Next on the keyboard moves to the next set's reps") {
            app.focus(firstReps)
            firstReps.typeText("10")
            app.buttons["keyboard.next"].tap()
            app.typeText("8")
            app.buttons["keyboard.done"].tap()
            XCTAssertEqual(firstReps.value as? String, "10")
            XCTAssertEqual(app.textFields["workout.exercise.0.set.1.reps"].value as? String, "8")
        }

        step("Minimize, visit another tab and resume with the sets intact") {
            app.buttons["workout.exercise.0.set.0.check"].tap()
            app.buttons["workout.minimize"].tap()
            XCTAssertFalse(app.buttons["workoutTab.startEmpty"].isEnabled)
            app.buttons["tabs.settings"].tap()
            app.buttons["tabs.workout"].tap()
            app.buttons["workoutTab.resume"].tap()
            XCTAssertTrue(firstReps.appears())
            XCTAssertEqual(firstReps.value as? String, "10")
            XCTAssertEqual(app.textFields["workout.exercise.0.set.1.reps"].value as? String, "8")
            XCTAssertEqual(app.buttons["workout.exercise.0.set.0.check"].value as? String, "done")
        }

        step("Discard asks first, then deletes the workout") {
            app.buttons["workout.menu"].tap()
            app.buttons["workout.discard"].tap()
            // The dialog's button appears twice in the accessibility tree (outer and inner node).
            app.buttons["workout.discardConfirm"].firstMatch.tap()
            let start = app.buttons["workoutTab.startEmpty"]
            XCTAssertTrue(start.appears())
            XCTAssertTrue(start.isEnabled)
            XCTAssertFalse(app.buttons["workoutTab.resume"].exists)
        }
    }
}
