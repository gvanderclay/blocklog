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

        step("Start a workout with three sets of Dumbbell Bench Press") {
            app.startWorkout()
            app.addExercise("Dumbbell Bench Press", as: 0)
            app.buttons["workout.exercise.0.addSet"].tap()
            app.buttons["workout.exercise.0.addSet"].tap()
        }

        let check0 = app.buttons["workout.exercise.0.set.0.check"]
        let check1 = app.buttons["workout.exercise.0.set.1.check"]
        let check2 = app.buttons["workout.exercise.0.set.2.check"]
        let secondReps = app.textFields["workout.exercise.0.set.1.reps"]
        let thirdReps = app.textFields["workout.exercise.0.set.2.reps"]
        let done = app.buttons["keyboard.done"]

        step("Next moves to the next set's reps without checking anything off") {
            app.focus(firstReps)
            firstReps.typeText("10")
            app.buttons["keyboard.next"].tap()
            app.typeText("8")
            XCTAssertEqual(check0.value as? String, "not done")
        }

        step("Done checks off the focused set and focuses the next set's reps") {
            done.tap()
            XCTAssertEqual(check1.value as? String, "done")
            XCTAssertEqual(secondReps.value as? String, "8")
            XCTAssertTrue(done.exists)  // the keyboard stays up, on the empty third set
            XCTAssertEqual(check0.value as? String, "not done")
        }

        step("Done on a set that can't be checked off closes the keyboard") {
            done.tap()
            XCTAssertTrue(done.waitForNonExistence(timeout: 5))
            XCTAssertEqual(check2.value as? String, "not done")
        }

        step("The checkmark checks off a set and focuses the next empty field") {
            check0.tap()
            XCTAssertEqual(check0.value as? String, "done")
            XCTAssertTrue(done.appears())
            app.typeText("5")
            XCTAssertEqual(thirdReps.value as? String, "5")
            done.tap()
            XCTAssertEqual(check2.value as? String, "done")
            XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        }

        step("Minimize, visit another tab and resume with the sets intact") {
            app.buttons["workout.minimize"].tap()
            XCTAssertFalse(app.buttons["workoutTab.startEmpty"].isEnabled)
            app.buttons["tabs.settings"].tap()
            app.buttons["tabs.workout"].tap()
            app.buttons["workoutTab.resume"].tap()
            XCTAssertTrue(firstReps.appears())
            XCTAssertEqual(firstReps.value as? String, "10")
            XCTAssertEqual(secondReps.value as? String, "8")
            XCTAssertEqual(check0.value as? String, "done")
        }

        step("Discard asks first, then deletes the workout") {
            app.buttons["workout.discardBottom"].tap()
            // The dialog's button appears twice in the accessibility tree (outer and inner node).
            app.buttons["workout.discardConfirm"].firstMatch.tap()
            let start = app.buttons["workoutTab.startEmpty"]
            XCTAssertTrue(start.appears())
            XCTAssertTrue(start.isEnabled)
            XCTAssertFalse(app.buttons["workoutTab.resume"].exists)
        }
    }
}
