import XCTest

/// UI flow 1 and the workout screen's resume and keyboard behaviour, on a fresh in-memory store.
final class WorkoutFlowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// UI flow 1, first part: log Dumbbell Bench Press with the PowerBlock picker and finish.
    @MainActor
    func testLogAndFinishAFreeformWorkout() {
        let app = launchAndStartWorkout(adding: "Dumbbell Bench Press")
        let plus = app.buttons["workout.exercise.0.set.0.weightPlus"]
        let weight = app.buttons["workout.exercise.0.set.0.weightValue"]
        XCTAssertEqual(weight.value as? String, "5 pounds")
        plus.tap()
        plus.tap()
        XCTAssertEqual(weight.value as? String, "10 pounds")
        plus.tap()
        XCTAssertEqual(weight.value as? String, "15 pounds")

        let reps = app.textFields["workout.exercise.0.set.0.reps"]
        app.focus(reps)
        reps.typeText("10")
        app.buttons["keyboard.done"].tap()
        app.buttons["workout.exercise.0.addSet"].tap()
        XCTAssertEqual(
            app.buttons["workout.exercise.0.set.1.weightValue"].value as? String, "15 pounds")
        XCTAssertEqual(app.textFields["workout.exercise.0.set.1.reps"].value as? String, "10")

        app.buttons["workout.exercise.0.set.0.check"].tap()
        app.buttons["workout.exercise.0.set.1.check"].tap()
        XCTAssertEqual(app.buttons["workout.exercise.0.set.1.check"].value as? String, "done")

        app.buttons["workout.finish"].tap()
        app.buttons["finish.save"].tap()
        let workoutNumber = app.staticTexts["summary.workoutNumber"]
        XCTAssertTrue(workoutNumber.waitForExistence(timeout: 5))
        XCTAssertEqual(workoutNumber.label, "Workout 1")
        app.buttons["summary.done"].tap()

        let start = app.buttons["workoutTab.startEmpty"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isEnabled)
        XCTAssertFalse(app.buttons["workoutTab.resume"].exists)

        // Previous numbers: the finished workout's sets show beside the new workout's sets.
        start.tap()
        app.buttons["workout.addExercise"].tap()
        XCTAssertTrue(app.buttons["exercisePicker.cancel"].waitForExistence(timeout: 5))
        app.pickExercise("Dumbbell Bench Press")
        XCTAssertTrue(
            app.buttons["workout.exercise.0.set.0.weightValue"].waitForExistence(timeout: 5))
        app.buttons["workout.exercise.0.addSet"].tap()
        let previous = app.buttons["workout.exercise.0.set.0.previous"]
        XCTAssertEqual(previous.value as? String, "15 pounds times 10")
        XCTAssertEqual(
            app.buttons["workout.exercise.0.set.1.previous"].value as? String,
            "15 pounds times 10")
        let newWeight = app.buttons["workout.exercise.0.set.0.weightValue"]
        XCTAssertEqual(newWeight.value as? String, "5 pounds")
        // The first set starts empty: the reps field reads its placeholder.
        XCTAssertEqual(app.textFields["workout.exercise.0.set.0.reps"].value as? String, "Reps")
        // The Previous column must not squeeze the weight value out of the row.
        XCTAssertTrue(newWeight.exists)
        XCTAssertGreaterThan(newWeight.frame.width, 0)

        previous.tap()
        XCTAssertEqual(
            app.buttons["workout.exercise.0.set.0.weightValue"].value as? String, "15 pounds")
        XCTAssertEqual(app.textFields["workout.exercise.0.set.0.reps"].value as? String, "10")
        XCTAssertGreaterThan(newWeight.frame.width, 0)
    }

    @MainActor
    func testMinimizedWorkoutResumesWithItsSets() {
        let app = launchAndStartWorkout(adding: "Dumbbell Bench Press")
        let reps = app.textFields["workout.exercise.0.set.0.reps"]
        app.focus(reps)
        reps.typeText("8")
        app.buttons["keyboard.done"].tap()
        app.buttons["workout.exercise.0.set.0.check"].tap()

        app.buttons["workout.minimize"].tap()
        XCTAssertFalse(app.buttons["workoutTab.startEmpty"].isEnabled)
        app.buttons["tabs.settings"].tap()
        app.buttons["tabs.workout"].tap()
        app.buttons["workoutTab.resume"].tap()

        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        XCTAssertEqual(reps.value as? String, "8")
        XCTAssertEqual(app.buttons["workout.exercise.0.set.0.check"].value as? String, "done")
    }

    @MainActor
    func testKeyboardNextFocusesTheNextRepsField() {
        let app = launchAndStartWorkout(adding: "Dumbbell Bench Press")
        app.buttons["workout.exercise.0.addSet"].tap()

        let first = app.textFields["workout.exercise.0.set.0.reps"]
        app.focus(first)
        first.typeText("10")
        app.buttons["keyboard.next"].tap()
        app.typeText("8")

        XCTAssertEqual(first.value as? String, "10")
        XCTAssertEqual(app.textFields["workout.exercise.0.set.1.reps"].value as? String, "8")
    }

    @MainActor
    func testDiscardAsksThenDeletesTheWorkout() {
        let app = launchAndStartWorkout(adding: "Dumbbell Bench Press")
        app.buttons["workout.menu"].tap()
        app.buttons["workout.discard"].tap()
        // The dialog's button appears twice in the accessibility tree (outer and inner node).
        app.buttons["workout.discardConfirm"].firstMatch.tap()

        let start = app.buttons["workoutTab.startEmpty"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isEnabled)
        XCTAssertFalse(app.buttons["workoutTab.resume"].exists)
    }

    /// Launches on a fresh store, starts an empty workout and adds one exercise.
    @MainActor
    private func launchAndStartWorkout(adding exercise: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let start = app.buttons["workoutTab.startEmpty"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        app.buttons["workout.addExercise"].tap()
        XCTAssertTrue(app.buttons["exercisePicker.cancel"].waitForExistence(timeout: 5))
        // The list is lazy: rows below the fold exist only once scrolled to.
        let row = app.buttons["exercisePicker.row.\(exercise)"]
        for _ in 0..<15 where !row.isHittable {
            app.swipeUp()
        }
        row.tap()
        XCTAssertTrue(
            app.buttons["workout.exercise.0.set.0.weightValue"].waitForExistence(timeout: 5))
        return app
    }
}
