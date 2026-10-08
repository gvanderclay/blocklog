import XCTest

extension XCUIApplication {
    /// A fresh app on an empty in-memory store with animations off, started on the Workout tab.
    @MainActor
    static func launchedForTesting() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    /// Quits and launches the app again keeping its saved settings (`-keep-defaults`), on a fresh empty store.
    @MainActor
    func relaunchKeepingDefaults() {
        terminate()
        launchArguments = ["-ui-testing", "-keep-defaults"]
        launch()
    }

    /// Taps Start Empty Workout on the Workout tab.
    @MainActor
    func startWorkout(file: StaticString = #filePath, line: UInt = #line) {
        let start = buttons["workoutTab.startEmpty"]
        XCTAssertTrue(start.appears(), file: file, line: line)
        start.tap()
    }

    /// Adds the exercise through the picker; it becomes exercise `index` in the workout.
    @MainActor
    func addExercise(
        _ name: String, as index: Int, file: StaticString = #filePath, line: UInt = #line
    ) {
        reveal(buttons["workout.addExercise"], swiping: { $0.swipeUp() })
        buttons["workout.addExercise"].tap()
        XCTAssertTrue(buttons["exercisePicker.cancel"].appears(), file: file, line: line)
        pickExercise(name, file: file, line: line)
        XCTAssertTrue(
            staticTexts["workout.exercise.\(index).name"].appears(), file: file, line: line)
    }

    /// Types digits into a field, then taps keyboard Done. Done checks the set off and may move focus to the next
    /// empty set instead of closing the keyboard, so callers must not assume the keyboard is gone.
    @MainActor
    func type(_ digits: String, into identifier: String) {
        let field = textFields[identifier]
        focus(field)
        field.typeText(digits)
        buttons["keyboard.done"].tap()  // also checks the set off, when it can be
    }

    /// Swipes until the element of the lazy list is hittable.
    @MainActor
    func reveal(_ element: XCUIElement, swiping swipe: (XCUIApplication) -> Void) {
        for _ in 0..<15 where !element.isHittable {
            swipe(self)
        }
    }
}
