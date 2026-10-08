import XCTest

/// Journey 1: log a workout, finish it, then start another and see and copy the previous numbers.
final class LogAndFinishJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLogFinishAndCopyPreviousNumbers() {
        let app = XCUIApplication.launchedForTesting()

        step("Start a workout and add Dumbbell Bench Press") {
            app.startWorkout()
            app.addExercise("Dumbbell Bench Press", as: 0)
            XCTAssertEqual(
                app.buttons["workout.exercise.0.set.0.weightValue"].value as? String, "5 pounds")
        }

        step("Step the weight up with + to 15 pounds") {
            let plus = app.buttons["workout.exercise.0.set.0.weightPlus"]
            plus.tap()
            plus.tap()
            plus.tap()
            XCTAssertEqual(
                app.buttons["workout.exercise.0.set.0.weightValue"].value as? String, "15 pounds")
        }

        step("Enter 10 reps and add a set that copies them") {
            app.type("10", into: "workout.exercise.0.set.0.reps")
            app.buttons["workout.exercise.0.addSet"].tap()
            XCTAssertEqual(
                app.buttons["workout.exercise.0.set.1.weightValue"].value as? String, "15 pounds")
            XCTAssertEqual(app.textFields["workout.exercise.0.set.1.reps"].value as? String, "10")
        }

        step("Check both sets off") {
            app.buttons["workout.exercise.0.set.0.check"].tap()
            app.buttons["workout.exercise.0.set.1.check"].tap()
            XCTAssertEqual(app.buttons["workout.exercise.0.set.1.check"].value as? String, "done")
        }

        step("Finish and save, see Workout 1, return to an idle Workout tab") {
            app.buttons["workout.finish"].tap()
            app.buttons["finish.save"].tap()
            let workoutNumber = app.staticTexts["summary.workoutNumber"]
            XCTAssertTrue(workoutNumber.appears())
            XCTAssertEqual(workoutNumber.label, "Workout 1")
            auditAccessibility(of: app, screen: "the finish summary") {
                $0.isSystemToolbarItem(["summary.done"])
                    || $0.isSecondaryText(["Duration", "Sets", "Exercises"])
            }
            app.buttons["summary.done"].tap()
            let start = app.buttons["workoutTab.startEmpty"]
            XCTAssertTrue(start.appears())
            XCTAssertTrue(start.isEnabled)
            XCTAssertFalse(app.buttons["workoutTab.resume"].exists)
        }

        step("Start another workout and see the previous numbers beside its sets") {
            app.startWorkout()
            app.addExercise("Dumbbell Bench Press", as: 0)
            app.buttons["workout.exercise.0.addSet"].tap()
            XCTAssertEqual(
                app.buttons["workout.exercise.0.set.0.previous"].value as? String,
                "15 pounds times 10")
            XCTAssertEqual(
                app.buttons["workout.exercise.0.set.1.previous"].value as? String,
                "15 pounds times 10")
            let newWeight = app.buttons["workout.exercise.0.set.0.weightValue"]
            XCTAssertEqual(newWeight.value as? String, "5 pounds")
            // The first set starts empty: the reps field reads its placeholder.
            XCTAssertEqual(app.textFields["workout.exercise.0.set.0.reps"].value as? String, "Reps")
            // The Previous column must not squeeze the weight value out of the row.
            XCTAssertGreaterThan(newWeight.frame.width, 0)
        }

        step("Tap the previous numbers to copy them into the set") {
            app.buttons["workout.exercise.0.set.0.previous"].tap()
            let weight = app.buttons["workout.exercise.0.set.0.weightValue"]
            XCTAssertEqual(weight.value as? String, "15 pounds")
            XCTAssertEqual(app.textFields["workout.exercise.0.set.0.reps"].value as? String, "10")
            XCTAssertGreaterThan(weight.frame.width, 0)
        }
    }
}
