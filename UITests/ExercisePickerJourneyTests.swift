import XCTest

/// Journey 2: find and create exercises in the picker.
///
/// SwiftUI gives the `.searchable` field no accessibility identifier (an identifier set on the list, the stack
/// or the field's modifiers doesn't reach it), so the journey finds it by its placeholder, "Search exercises".
final class ExercisePickerJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFindAndCreateExercises() {
        let app = XCUIApplication.launchedForTesting()

        step("Open the picker from a new workout") {
            app.startWorkout()
            app.buttons["workout.addExercise"].tap()
            XCTAssertTrue(app.buttons["exercisePicker.cancel"].appears())
        }

        // Audited in its default, unfiltered, scrolling state.
        auditAccessibility(of: app, screen: "the exercise picker (unfiltered)") {
            $0.isSystemToolbarItem(["exercisePicker.cancel"])
                || $0.isSystemControl(["Search exercises"])
                || $0.isPickerRowUnderBottomBar("exercisePicker.row.Chin-up")
        }

        step("The Pull-up bar filter hides dumbbell exercises") {
            app.buttons["exercisePicker.equipmentFilter"].tap()
            app.buttons["Pull-up bar"].tap()
            XCTAssertTrue(app.buttons["exercisePicker.row.Pull-up"].appears())
            XCTAssertTrue(app.buttons["exercisePicker.row.Dumbbell Bench Press"].disappears())
        }

        // Audited with the short filtered list: in the full list the last visible row scrolls under the bottom bar,
        // where the audit measures its contrast against the bar.
        auditAccessibility(of: app, screen: "the exercise picker") {
            $0.isSystemToolbarItem(["exercisePicker.cancel"])
                || $0.isSystemControl(["Search exercises"])
        }

        step("All brings the dumbbell exercises back") {
            app.buttons["exercisePicker.equipmentFilter"].tap()
            app.buttons["All"].tap()
            XCTAssertTrue(app.buttons["exercisePicker.row.Dumbbell Bench Press"].appears())
        }

        step("A duplicate name shows the error and disables Save") {
            app.buttons["exercisePicker.new"].tap()
            let name = app.textFields["newExercise.name"]
            XCTAssertTrue(name.appears())
            name.tap()
            let duplicate = "dumbbell bench press"
            name.typeText(duplicate)
            XCTAssertTrue(app.staticTexts["newExercise.error"].appears())
            XCTAssertFalse(app.buttons["newExercise.save"].isEnabled)
            name.typeText(
                String(repeating: XCUIKeyboardKey.delete.rawValue, count: duplicate.count))
            XCTAssertTrue(app.staticTexts["newExercise.error"].disappears())
        }

        auditAccessibility(of: app, screen: "the new-exercise form") {
            $0.isSystemToolbarItem(["newExercise.save"]) || $0.isSystemControl(["Weight × Reps"])
        }

        step("Create Test Row under Shoulders and see it added to the workout") {
            let name = app.textFields["newExercise.name"]
            // The audit dropped the keyboard focus.
            name.tap()
            name.typeText("Test Row\n")
            app.buttons["newExercise.muscleGroup"].tap()
            // Shoulders, not Back: a "Back" row is ambiguous with the navigation back button.
            app.buttons["Shoulders"].tap()
            app.buttons["newExercise.save"].tap()
            XCTAssertTrue(app.buttons["workout.addExercise"].appears())
            XCTAssertEqual(app.staticTexts["workout.exercise.0.name"].label, "Test Row")
        }

        step("Reopen the picker; search narrows the list and shows Test Row under Shoulders") {
            app.buttons["workout.addExercise"].tap()
            let search = app.searchFields["Search exercises"]
            XCTAssertTrue(search.appears())
            search.tap()
            // Return dismisses the keyboard; pushing with it up stalls XCTest's idle wait for 60 s.
            search.typeText("curl\n")
            XCTAssertTrue(app.buttons["exercisePicker.row.Dumbbell Curl"].appears())
            XCTAssertTrue(app.buttons["exercisePicker.row.Dumbbell Bench Press"].disappears())

            search.tap()
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
            search.typeText("Test Row\n")
            XCTAssertTrue(app.buttons["exercisePicker.row.Test Row"].appears())
            XCTAssertTrue(app.staticTexts["Shoulders"].exists)
        }
    }
}
