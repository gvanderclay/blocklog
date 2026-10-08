import XCTest

/// Exercise kinds, set types and in-workout editing, on a fresh in-memory store.
final class WorkoutEditingTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLogBodyweightAndDurationSets() {
        let app = launchAndStartWorkout()
        addExercise("Pull-up", as: 0, to: app)
        let value = app.buttons["workout.exercise.0.set.0.addedWeightValue"]
        XCTAssertEqual(value.value as? String, "bodyweight")
        XCTAssertFalse(app.buttons["workout.exercise.0.set.0.addedWeightMinus"].isEnabled)
        type("8", into: "workout.exercise.0.set.0.reps", app)
        app.buttons["workout.exercise.0.set.0.check"].tap()

        app.buttons["workout.exercise.0.addSet"].tap()
        let second = app.buttons["workout.exercise.0.set.1.addedWeightValue"]
        XCTAssertEqual(second.value as? String, "bodyweight")
        app.buttons["workout.exercise.0.set.1.addedWeightPlus"].tap()
        XCTAssertEqual(second.value as? String, "5 pounds")
        XCTAssertEqual(app.textFields["workout.exercise.0.set.1.reps"].value as? String, "8")
        app.buttons["workout.exercise.0.set.1.check"].tap()

        addExercise("Plank", as: 1, to: app)
        let check = app.buttons["workout.exercise.1.set.0.check"]
        XCTAssertFalse(check.isEnabled)
        type("45", into: "workout.exercise.1.set.0.duration", app)
        XCTAssertTrue(check.isEnabled)
        check.tap()

        for id in [
            "workout.exercise.0.set.0.check", "workout.exercise.0.set.1.check",
            "workout.exercise.1.set.0.check",
        ] {
            XCTAssertEqual(app.buttons[id].value as? String, "done", id)
        }
    }

    @MainActor
    func testWarmUpNumberingSwipeDeleteAndReorder() {
        let app = launchAndStartWorkout()
        addExercise("Dumbbell Bench Press", as: 0, to: app)
        app.buttons["workout.exercise.0.addSet"].tap()
        app.buttons["workout.exercise.0.addSet"].tap()

        app.buttons["workout.exercise.0.set.0.typeMenu"].tap()
        app.buttons["setMenu.type.warmUp"].tap()
        XCTAssertEqual(app.buttons["workout.exercise.0.set.0.typeMenu"].value as? String, "W")
        XCTAssertEqual(app.buttons["workout.exercise.0.set.1.typeMenu"].value as? String, "1")
        XCTAssertEqual(app.buttons["workout.exercise.0.set.2.typeMenu"].value as? String, "2")

        row(containing: "workout.exercise.0.set.2.check", in: app).swipeLeft()
        let delete = app.buttons["setMenu.delete"]
        if delete.waitForExistence(timeout: 2) { delete.tap() }
        XCTAssertTrue(
            app.buttons["workout.exercise.0.set.2.check"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["workout.exercise.0.set.1.check"].exists)

        addExercise("Hammer Curl", as: 1, to: app)
        app.buttons["workout.menu"].tap()
        app.buttons["workout.reorder"].tap()
        let first = app.staticTexts["reorder.row.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.label, "Dumbbell Bench Press")
        // Drag the second row's reorder handle onto the first row's.
        // The system labels each handle "Reorder <row text>"; it has no identifier.
        let bench = app.buttons["Reorder Dumbbell Bench Press"]
        let curl = app.buttons["Reorder Hammer Curl"]
        XCTAssertTrue(curl.waitForExistence(timeout: 5))
        curl.press(forDuration: 1, thenDragTo: bench)
        XCTAssertEqual(app.staticTexts["reorder.row.0"].label, "Hammer Curl")
        app.buttons["reorder.done"].tap()
        XCTAssertTrue(app.staticTexts["workout.exercise.0.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["workout.exercise.0.name"].label, "Hammer Curl")
        XCTAssertEqual(app.staticTexts["workout.exercise.1.name"].label, "Dumbbell Bench Press")
    }

    @MainActor
    func testContextMenuDuplicatesAndDeletes() {
        let app = launchAndStartWorkout()
        addExercise("Dumbbell Bench Press", as: 0, to: app)
        type("10", into: "workout.exercise.0.set.0.reps", app)
        XCTAssertFalse(app.buttons["workout.exercise.0.set.1.check"].exists)

        longPress(
            row(containing: "workout.exercise.0.set.0.check", in: app),
            setPrefix: "workout.exercise.0.set.0", in: app)
        app.buttons["setMenu.duplicate"].tap()
        XCTAssertTrue(app.buttons["workout.exercise.0.set.1.check"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["workout.exercise.0.set.1.reps"].value as? String, "10")

        longPress(
            row(containing: "workout.exercise.0.set.1.check", in: app),
            setPrefix: "workout.exercise.0.set.1", in: app)
        app.buttons["setMenu.delete"].tap()
        XCTAssertTrue(
            app.buttons["workout.exercise.0.set.1.check"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["workout.exercise.0.set.0.check"].exists)
    }

    @MainActor
    func testRemoveExerciseConfirmsOnlyWhenASetIsChecked() {
        let app = launchAndStartWorkout()
        addExercise("Dumbbell Bench Press", as: 0, to: app)
        addExercise("Hammer Curl", as: 1, to: app)
        app.buttons["workout.exercise.1.menu"].tap()
        app.buttons["workout.exercise.1.remove"].tap()
        XCTAssertTrue(app.staticTexts["workout.exercise.1.name"].waitForNonExistence(timeout: 5))

        type("10", into: "workout.exercise.0.set.0.reps", app)
        app.buttons["workout.exercise.0.set.0.check"].tap()
        app.buttons["workout.exercise.0.menu"].tap()
        app.buttons["workout.exercise.0.remove"].tap()
        let confirm = app.buttons["workout.exercise.0.removeConfirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["workout.exercise.0.name"].waitForNonExistence(timeout: 5))
    }

    // MARK: Helpers

    @MainActor
    private func launchAndStartWorkout() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let start = app.buttons["workoutTab.startEmpty"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        return app
    }

    /// Adds the exercise through the picker; it becomes exercise `index` in the workout.
    @MainActor
    private func addExercise(_ name: String, as index: Int, to app: XCUIApplication) {
        app.buttons["workout.addExercise"].tap()
        XCTAssertTrue(app.buttons["exercisePicker.cancel"].waitForExistence(timeout: 5))
        app.pickExercise(name)
        XCTAssertTrue(
            app.staticTexts["workout.exercise.\(index).name"].waitForExistence(timeout: 5))
    }

    /// Types digits into a field and dismisses the keyboard, which would otherwise stall later taps.
    @MainActor
    private func type(_ digits: String, into identifier: String, _ app: XCUIApplication) {
        let field = app.textFields[identifier]
        app.focus(field)
        field.typeText(digits)
        app.buttons["keyboard.done"].tap()
    }

    /// The list row holding the element with the identifier.
    @MainActor
    private func row(containing identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(NSPredicate(format: "identifier == %@", identifier)).firstMatch
    }

    /// A long press on the row's gap between its weight control and its reps or duration field, which
    /// belongs to no button. `prefix` is `workout.exercise.<e>.set.<s>`.
    @MainActor
    private func longPress(_ row: XCUIElement, setPrefix prefix: String, in app: XCUIApplication) {
        let plus = ["weightPlus", "addedWeightPlus"].map { app.buttons["\(prefix).\($0)"] }
            .first(where: \.exists)
        let field = ["reps", "duration"].map { app.textFields["\(prefix).\($0)"] }
            .first(where: \.exists)
        guard let plus, let field else { return XCTFail("no weight control or field in \(prefix)") }
        let x = (plus.frame.maxX + field.frame.minX) / 2
        let origin = row.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: x - row.frame.minX, dy: row.frame.height / 2))
            .press(forDuration: 1)
    }
}
