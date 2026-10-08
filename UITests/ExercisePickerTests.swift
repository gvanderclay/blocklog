import XCTest

/// The exercise picker and the new-exercise form, on a fresh in-memory store.
///
/// SwiftUI gives the `.searchable` field no accessibility identifier (an identifier set on the list, the stack
/// or the field's modifiers doesn't reach it), so the tests find it by its placeholder, "Search exercises".
final class ExercisePickerTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSearchShowsOnlyNamesContainingTheText() {
        let app = openPicker()
        let search = app.searchFields["Search exercises"]
        search.tap()
        search.typeText("curl")

        XCTAssertTrue(app.buttons["exercisePicker.row.Dumbbell Curl"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["exercisePicker.row.Dumbbell Bench Press"].waitForNonExistence(timeout: 5))
        let rows = pickerRowIdentifiers(app)
        XCTAssertFalse(rows.isEmpty)
        for identifier in rows {
            XCTAssertTrue(identifier.localizedCaseInsensitiveContains("curl"), identifier)
        }
    }

    @MainActor
    func testPullUpBarFilterHidesDumbbellExercises() {
        let app = openPicker()
        app.buttons["exercisePicker.equipmentFilter"].tap()
        app.buttons["Pull-up bar"].tap()

        // Only the five pull-up bar exercises in the starter list.
        XCTAssertTrue(app.buttons["exercisePicker.row.Pull-up"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["exercisePicker.row.Dumbbell Bench Press"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(
            Set(pickerRowIdentifiers(app)),
            [
                "exercisePicker.row.Chin-up", "exercisePicker.row.Pull-up",
                "exercisePicker.row.Hanging Knee Raise", "exercisePicker.row.Hanging Leg Raise",
                "exercisePicker.row.Dead Hang",
            ])
    }

    @MainActor
    func testCreatedExerciseAddsToWorkoutAndListsUnderItsGroup() {
        let app = openPicker()
        app.buttons["exercisePicker.new"].tap()
        let name = app.textFields["newExercise.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        // Return dismisses the keyboard; pushing with it up stalls XCTest's idle wait for 60 s.
        name.typeText("Test Row\n")
        app.buttons["newExercise.muscleGroup"].tap()
        // Shoulders, not Back: a "Back" row is ambiguous with the navigation back button.
        app.buttons["Shoulders"].tap()
        app.buttons["newExercise.save"].tap()

        // The form saved, the picker dismissed, and the workout got the new exercise.
        XCTAssertTrue(app.buttons["workout.addExercise"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["workout.exercise.0.name"].label, "Test Row")

        app.buttons["workout.addExercise"].tap()
        let search = app.searchFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Test Row")
        let row = app.buttons["exercisePicker.row.Test Row"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        // Only the Shoulders header is left, so the row sits under it and no other group shows.
        let header = app.staticTexts["Shoulders"]
        XCTAssertTrue(header.exists)
        XCTAssertFalse(app.staticTexts["Chest"].exists)
        XCTAssertLessThan(header.frame.minY, row.frame.minY)
    }

    @MainActor
    func testDuplicateNameShowsErrorAndDisablesSave() {
        let app = openPicker()
        app.buttons["exercisePicker.new"].tap()
        let name = app.textFields["newExercise.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("dumbbell bench press")

        XCTAssertTrue(app.staticTexts["newExercise.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["newExercise.save"].isEnabled)
    }

    /// Launches on a fresh store, starts an empty workout and opens the picker.
    @MainActor
    private func openPicker() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let start = app.buttons["workoutTab.startEmpty"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        app.buttons["workout.addExercise"].tap()
        XCTAssertTrue(app.buttons["exercisePicker.cancel"].waitForExistence(timeout: 5))
        return app
    }

    /// The identifiers of the picker's rows currently in the accessibility tree.
    @MainActor
    private func pickerRowIdentifiers(_ app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'exercisePicker.row.'"))
            .allElementsBoundByIndex.map(\.identifier)
    }
}
