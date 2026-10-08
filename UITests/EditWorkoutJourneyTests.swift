import XCTest

/// Journey 3: edit a workout with every exercise kind: set types, swipe, duplicate and delete, remove and reorder.
final class EditWorkoutJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEditAWorkoutOfEveryKind() {
        let app = XCUIApplication.launchedForTesting()

        step("Start a workout with a bodyweight, a duration and two dumbbell exercises") {
            app.startWorkout()
            app.addExercise("Pull-up", as: 0)
            app.addExercise("Plank", as: 1)
            app.addExercise("Dumbbell Bench Press", as: 2)
            app.addExercise("Hammer Curl", as: 3)
        }

        auditAccessibility(of: app, screen: "the workout screen") {
            $0.isSystemToolbarItem(["workout.finish", "workout.elapsed"])
        }

        step("Remove an exercise with no checked set without a confirmation") {
            app.buttons["workout.exercise.3.menu"].tap()
            app.buttons["workout.exercise.3.remove"].tap()
            XCTAssertTrue(app.staticTexts["workout.exercise.3.name"].disappears())
        }

        step("Log bodyweight sets, stepping the added weight on the second") {
            XCTAssertEqual(
                app.buttons["workout.exercise.0.set.0.addedWeightValue"].value as? String,
                "bodyweight")
            XCTAssertFalse(app.buttons["workout.exercise.0.set.0.addedWeightMinus"].isEnabled)
            app.type("8", into: "workout.exercise.0.set.0.reps")  // Done also checks the set off
            app.buttons["workout.exercise.0.addSet"].tap()
            let second = app.buttons["workout.exercise.0.set.1.addedWeightValue"]
            XCTAssertEqual(second.value as? String, "bodyweight")
            app.buttons["workout.exercise.0.set.1.addedWeightPlus"].tap()
            XCTAssertEqual(second.value as? String, "5 pounds")
            XCTAssertEqual(app.textFields["workout.exercise.0.set.1.reps"].value as? String, "8")
            app.buttons["workout.exercise.0.set.1.check"].tap()
        }

        step("Log a duration set, which checks off only once it has seconds") {
            let check = app.buttons["workout.exercise.1.set.0.check"]
            XCTAssertFalse(check.isEnabled)
            app.type("45", into: "workout.exercise.1.set.0.duration")
            XCTAssertTrue(check.isEnabled)  // Done on the keyboard has checked it off
            for id in [
                "workout.exercise.0.set.0.check", "workout.exercise.0.set.1.check",
                "workout.exercise.1.set.0.check",
            ] {
                // The list scrolls down to the next empty field, so the first rows can be off screen.
                app.reveal(app.buttons[id], swiping: { $0.swipeDown() })
                XCTAssertEqual(app.buttons[id].value as? String, "done", id)
            }
        }

        step("Remove an exercise with checked sets only after confirming") {
            // Done on the Plank moved focus to the bench press's empty reps, under the keyboard. On CI that
            // makes the list scroll to it once the menu opens, which takes the header (and the dialog it
            // presents) off screen. Done on empty reps closes the keyboard.
            if app.buttons["keyboard.done"].exists { app.buttons["keyboard.done"].tap() }
            XCTAssertTrue(app.keyboards.firstMatch.disappears())
            let menu = app.buttons["workout.exercise.0.menu"]
            app.reveal(menu, swiping: { $0.swipeDown() })
            menu.tap()
            app.buttons["workout.exercise.0.remove"].tap()
            let confirm = app.buttons["workout.exercise.0.removeConfirm"].firstMatch
            XCTAssertTrue(confirm.appears())
            confirm.tap()
            // Plank is now first and the bench press second.
            XCTAssertEqual(app.staticTexts["workout.exercise.0.name"].label, "Plank")
        }

        step("Make the bench press's first set a warm-up and see the numbering") {
            app.buttons["workout.exercise.1.addSet"].tap()
            app.buttons["workout.exercise.1.addSet"].tap()
            app.buttons["workout.exercise.1.set.0.typeMenu"].tap()
            app.buttons["setMenu.type.warmUp"].tap()
            XCTAssertEqual(
                app.buttons["workout.exercise.1.set.0.typeMenu"].value as? String, "W")
            XCTAssertEqual(app.buttons["workout.exercise.1.set.1.typeMenu"].value as? String, "1")
            XCTAssertEqual(app.buttons["workout.exercise.1.set.2.typeMenu"].value as? String, "2")
        }

        step("Swipe the last bench press set away") {
            let last = app.buttons["workout.exercise.1.set.2.check"]
            row(containing: "workout.exercise.1.set.2.check", in: app).swipeLeft()
            // A full swipe deletes at once; a short one leaves the Delete button to tap.
            let delete = app.buttons["setMenu.delete"]
            if !last.disappears(timeout: 1), delete.exists { delete.tap() }
            XCTAssertTrue(last.disappears())
            XCTAssertTrue(app.buttons["workout.exercise.1.set.1.check"].exists)
        }

        step("Duplicate the first bench press set from its menu, then delete the copy") {
            app.type("10", into: "workout.exercise.1.set.0.reps")
            XCTAssertFalse(app.buttons["workout.exercise.1.set.2.check"].exists)
            longPress(
                row(containing: "workout.exercise.1.set.0.check", in: app),
                setPrefix: "workout.exercise.1.set.0", in: app)
            app.buttons["setMenu.duplicate"].tap()
            XCTAssertTrue(app.buttons["workout.exercise.1.set.2.check"].appears())
            XCTAssertEqual(app.textFields["workout.exercise.1.set.1.reps"].value as? String, "10")

            longPress(
                row(containing: "workout.exercise.1.set.1.check", in: app),
                setPrefix: "workout.exercise.1.set.1", in: app)
            app.buttons["setMenu.delete"].tap()
            XCTAssertTrue(app.buttons["workout.exercise.1.set.2.check"].disappears())
            XCTAssertTrue(app.buttons["workout.exercise.1.set.1.check"].exists)
        }

        step("Reorder the two left by dragging Dumbbell Bench Press above Plank") {
            app.buttons["workout.menu"].tap()
            app.buttons["workout.reorder"].tap()
            let first = app.staticTexts["reorder.row.0"]
            XCTAssertTrue(first.appears())
            XCTAssertEqual(first.label, "Plank")
            // The system labels each reorder handle "Reorder <row text>"; it has no identifier.
            let plank = app.buttons["Reorder Plank"]
            let bench = app.buttons["Reorder Dumbbell Bench Press"]
            XCTAssertTrue(bench.appears())
            bench.press(forDuration: 1, thenDragTo: plank)
            XCTAssertEqual(app.staticTexts["reorder.row.0"].label, "Dumbbell Bench Press")
            app.buttons["reorder.done"].tap()
            XCTAssertTrue(app.staticTexts["workout.exercise.0.name"].appears())
            XCTAssertEqual(app.staticTexts["workout.exercise.0.name"].label, "Dumbbell Bench Press")
            XCTAssertEqual(app.staticTexts["workout.exercise.1.name"].label, "Plank")
        }
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
